# Load the Rails application.
require File.expand_path('../application', __FILE__)
require 'open_chain/test_extensions'
require 'open_chain/cache_wrapper'

Dir.mkdir("log") unless Dir.exist?("log")
Dir.mkdir("tmp") unless Dir.exist?("tmp")

# This is required to allow New Relic access to Garbage Collection timings / statistics
GC::Profiler.enable

if Rails.env.development?
  # Validate memcache is running - on a first install on dev computer, you might not have memcache installed.
  CACHE = CacheWrapper.ensure_memcache_access
else
  CACHE = CacheWrapper.new(Rails.env.test? ? TestExtensions::MockCache.new : CacheWrapper.get_production_client)
end

# Initialize the Rails application.
Rails.application.initialize!

if Rails.env.development?
  # Ensure redis is running...otherwise many things will fail.  Only dev since that's the only environment where redis may actually not be there
  # (like on first time start-ups)
  Lock.ensure_redis_access
end
