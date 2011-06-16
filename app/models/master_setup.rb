class MasterSetup < ActiveRecord::Base

  CACHE_KEY = "MasterSetup:setup"

  after_update :update_cache 
  after_find :update_cache

  def version
    Rails.root.join("config","version.txt").read
  end

  def self.get
    m = CACHE.get CACHE_KEY 
    raise "MasterSetup cache returned a #{m.class} !" if !m.nil? && !m.is_a?(MasterSetup)
    if m.nil?
      m = init_base_setup
      CACHE.set CACHE_KEY, m if cache_initalized
    elsif !m.is_a?(MasterSetup)
      logger.info "#{Time.now}: MasterSetup returned a #{m.class}"
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
