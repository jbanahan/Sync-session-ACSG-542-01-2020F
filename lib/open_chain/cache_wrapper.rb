require 'open_chain/test_extensions'
require 'open_chain/cache_wrapper'

class CacheWrapper

  def initialize(cache)
    @cache = cache
  end

  def set key, val
    error_wrap {@cache.set key, val}
  end

  def get key
    error_wrap {@cache.get key}
  end

  def delete key
    error_wrap {@cache.delete key}
  end

  def reset
    @cache.reset
  end
  
  def self.get_production_client file_path = 'config/memcached.yml'
    settings = memcache_settings file_path
    Dalli::Client.new(["#{settings["server"]}:#{settings["port"]}"], {:namespace=>settings["namespace"], :compress=>true})
  end

  def self.memcache_settings file_path
    # Load memcached settings from config/memcached.yml
    ver = File.exists?('config/version.txt') ? IO.read('config/version.txt').strip : "NOVERSION" 
    settings = (file_path && File.exists?(file_path)) ? YAML::load(File.open(file_path))[Rails.env] : {}
    settings = {"server"=>"localhost", "port"=>"11211", "namespace" => "#{Rails.root.basename}-#{ver}"}.merge settings
  end
  private_class_method :memcache_settings

  def self.ensure_memcache_access
    client = get_production_client
    begin
      # Just attempt any get...we're just checking if memcache is running or not here...that's it.
      client.get 't'
    rescue Dalli::RingError => e
      settings = memcache_settings(nil)
      raise "Memcache does not appear to be running.  Please ensure it is installed and running at #{settings["server"]}:#{settings["port"]}."
    end
    self.new(client)
  end

  private
  def error_wrap &block
    retried = false
    begin
      return yield
    rescue Dalli::RingError
      if retried
        $!.log_me ["Second ring error, swallowing.  The process continued without cache result."]
      else
        reset
        retried = true
        retry
      end
    rescue
      $!.log_me ["Swallowed by open_chain/cache_wrapper. The process continued without cache result."]
    end
    return nil
  end

end
