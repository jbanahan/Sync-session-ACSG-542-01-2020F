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

  def self.need_upgrade?
    ms = MasterSetup.get
    !ms.target_version.blank? && ms.version.strip!=ms.target_version.strip
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

  # checks to see if the given custom feature is in the custom features list
  def custom_feature? feature
    custom_features_list.include? feature
  end
  # get the custom features enabled for this system as an array
  def custom_features_list
    return [] if self.custom_features.blank?
    return self.custom_features.lines
  end

  # set the custom features enabled for this system by passing an array or a string
  def custom_features_list= data
    d = data
    if data.respond_to? 'join'
      d = data.join('\n')
    elsif data.respond_to? 'gsub'
      d = data.gsub('\r','\n')
    end
    self.custom_features = d
  end

  private
  def update_cache
    CACHE.set CACHE_KEY, self
  end
end
