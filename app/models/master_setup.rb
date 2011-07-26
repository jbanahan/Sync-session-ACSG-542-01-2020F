class MasterSetup < ActiveRecord::Base

  CACHE_KEY = "MasterSetup:setup"

  after_update :update_cache 
  after_find :update_cache

  def version
    Rails.root.join("config","version.txt").read
  end

  #get the master setup for this instance, first trying the cache, then trying the DB, then creating and returning a new one
  def self.get
    m = nil
    begin
      m = CACHE.get CACHE_KEY 
    rescue
    end
    if m.nil? || !m.is_a?(MasterSetup)
      m = init_base_setup
      CACHE.set CACHE_KEY, m 
    end
    m.is_a?(MasterSetup) ? m : MasterSetup.first
  end

  def self.get_migration_lock hostname=nil
    h = hostname.blank? ? `hostname`.strip : hostname
    c = MasterSetup.connection
    begin
      c.execute "LOCK TABLES master_setups WRITE;"
      c.execute "UPDATE master_setups SET migration_host = '#{h}' WHERE migration_host is null;"
      found_host = c.execute("SELECT migration_host FROM master_setups;").first.first
      return found_host==h
    ensure
      c.execute "UNLOCK TABLES;"
      MasterSetup.first #makes sure the after_find callback is called to update the cache
    end
  end

  def self.release_migration_lock
    c = MasterSetup.connection
    begin
      c.execute "LOCK TABLES master_setups WRITE;"
      c.execute "UPDATE master_setups SET migration_host = null;"
    ensure
      c.execute "UNLOCK TABLES;"
      MasterSetup.first #makes sure the after_find callback is called to update the cache
    end
  end

  def self.init_base_setup
    m = MasterSetup.first
    if m.nil?
      m = MasterSetup.create!(:uuid => UUIDTools::UUID.timestamp_create.to_s)
    end
    m
  end

  private
  def update_cache
    CACHE.set CACHE_KEY, self
  end
end
