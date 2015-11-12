class MasterSetup < ActiveRecord::Base
  cattr_accessor :current

  CACHE_KEY = "MasterSetup:setup"

  after_update :update_cache
  after_find :update_cache

  def self.current_config_version
    Rails.root.join("config","version.txt").read.strip
  end

  # We want to make sure the version # never updates.  The version the config file stated
  # when this code was loaded is always the version # we care to relay.  This is especially
  # important during an upgrade when the version number on disk my not exactly match what's
  # code is currently running.
  CURRENT_VERSION ||= current_config_version

  def self.current_code_version
    CURRENT_VERSION
  end

  #get the master setup for this instance, first trying the cache, then trying the DB, then creating and returning a new one
  def self.get use_in_memory_version=true
    m = (use_in_memory_version ? MasterSetup.current : nil)
    begin
      m = CACHE.get CACHE_KEY unless m
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
    ms = MasterSetup.get(false)
    !ms.target_version.blank? && current_code_version.strip!=ms.target_version.strip
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
      if User.scoped.empty?
        c = Company.first_or_create!(name:'My Company',master:true)
        if c.users.empty?
          pass = 'init_pass'
          u = c.users.build(:username=>"chainio_admin",:email=>"support@vandegriftinc.com")
          u.password = pass
          u.sys_admin = true
          u.admin = true
          u.save
          OpenMailer.send_new_system_init(pass).deliver if Rails.env=="production"
        end
      end
    end
    m
  end

  # checks to see if the given custom feature is in the custom features list
  def custom_feature? feature
    custom_features_list.map {|l| l.upcase}.include? feature.to_s.upcase
  end
  
  # get the custom features enabled for this system as an array
  def custom_features_list
    return [] if self.custom_features.blank?
    features = self.custom_features.split($/).to_a
    features.collect {|f| f.strip}

  end

  # set the custom features enabled for this system by passing an array or a string
  def custom_features_list= data
    d = data
    if data.respond_to? 'join'
      d = data.join($/)
    elsif data.respond_to? "gsub"
      d = data.gsub("\r\n",$/).gsub("\r",$/).gsub("\n",$/)
    end
    self.custom_features = d
  end

  private
  def update_cache
    CACHE.set CACHE_KEY, self
  end
end
