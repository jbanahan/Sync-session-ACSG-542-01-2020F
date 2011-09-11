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
    # Load memcached settings from config/memcached.yml
    ver = File.exists?('tmp/version.txt') ? IO.read('tmp/version.txt').strip : "NOVERSION" 
    settings = File.exists?(file_path) ? YAML::load(File.open(file_path))[Rails.env] : {}
    settings = {"server"=>"localhost", "port"=>"11211"}.merge settings
    Dalli::Client.new(["#{settings["server"]}:#{settings["port"]}"], {:namespace=>"#{ver}#{Rails.root.basename}"})
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
