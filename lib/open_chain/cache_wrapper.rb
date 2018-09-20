require 'dalli-elasticache'
require 'open_chain/test_extensions'
require 'open_chain/cache_wrapper'
require 'open_chain/database_utils'
require 'open_chain/git'

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
  
  def self.get_production_client 
    server, settings = memcache_settings()
    Dalli::Client.new(server, settings)
  end

  def self.memcache_settings file_path: 'config/memcached.yml'
    # Load memcached settings from config/memcached.yml
    settings = (file_path && File.exist?(file_path)) ? YAML::load(File.open(file_path))[Rails.env] : {}
    raise "No memcache client configuration file found at '#{file_path}'." unless File.exist?(file_path)

    settings = YAML::load(File.open(file_path))[Rails.env]
    raise "No memcache client configuration found in file '#{file_path}' for Rails '#{Rails.env}' environment." if settings.blank?

    # This is an AWS Elasticache'ism...we can use Elasticache Automatic Discovery protocol to determine what cache cluster nodes to utilize, rather than coding
    # node endpoints directly into our configuration
    server = nil
    if !settings["configuration_endpoint"].blank?
      endpoint = settings.delete "configuration_endpoint"
      elasticache = Dalli::ElastiCache.new(endpoint, settings.symbolize_keys)
      server = elasticache.servers
    else
      server = Array.wrap(settings.delete "server")
    end

    settings["namespace"] = memcache_namespace
    settings["compress"] = true
    settings = settings.symbolize_keys

    [server, settings]
  end

  def self.memcache_namespace
    # In order to ensure we don't have cache contention across different test/production systems we need the database endpoint / database
    # name and code version as part of our namespace calculation

    # We'll just use the first hostname from the database config as the database name
    db_config = OpenChain::DatabaseUtils.primary_database_configuration
    db_host = "#{db_config[:host]}-#{db_config[:port]}"
    db_name = db_config[:database]
    code_version = OpenChain::Git.current_tag_name(allow_branch_name: true)

    raise "Invalid memcache namespace configuration DB Host #{db_host} / DB Name #{db_name} / Version #{code_version}" if db_host.blank? || db_name.blank? || code_version.blank?
    "#{db_host}-#{db_name}-#{code_version}"
  end
  private_class_method :memcache_namespace

  def self.ensure_memcache_access
    client = get_production_client
    begin
      # Just attempt any get...we're just checking if memcache is running or not here...that's it.
      client.get 't'
    rescue Dalli::RingError => e
      settings = memcache_settings
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
