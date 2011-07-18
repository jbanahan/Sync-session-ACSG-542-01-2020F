class MasterSetup < ActiveRecord::Base

  CACHE_KEY = "MasterSetup:setup"

  after_update :update_cache 
  after_find :update_cache

  def version
    Rails.root.join("config","version.txt").read
  end

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
