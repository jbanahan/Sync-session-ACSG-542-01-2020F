class CacheManager

  def self.namespace
    u = MasterSetup.get.uuid
    u = touch_time << u if Rails.env=="production"
    u
  end

  private
  def self.touch_time
    f = File.new("tmp/restart.txt")
    f.nil? ? Time.now.to_i.to_s : f.mtime.to_i.to_s
  end
end
