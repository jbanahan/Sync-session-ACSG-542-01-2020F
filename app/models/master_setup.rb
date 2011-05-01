class MasterSetup < ActiveRecord::Base

  CACHE_KEY = "master_setup"

  def version
    Rails.root.join("config","version.txt").read
  end

  def self.get
    m = nil
    cache_initalized = true
    begin
      m = CACHE.get CACHE_KEY 
      return m unless m.nil?
    rescue NameError
      cache_initalized = false
    end
    m = init_base_setup
    CACHE.set CACHE_KEY, m if cache_initalized
    m
  end

  def self.init_base_setup
    m = MasterSetup.first
    if m.nil?
      m = MasterSetup.create!(:uuid => UUIDTools::UUID.timestamp_create.to_s)
    end
    m
  end
end
