# Load the rails application
require File.expand_path('../application', __FILE__)
require 'open_chain/test_extensions'
require 'open_chain/cache_wrapper'
require 'mono_logger'

Dir.mkdir("log") unless Dir.exist?("log")
Dir.mkdir("tmp") unless Dir.exist?("tmp")

GC::Profiler.enable

# Initialize the rails application
if Rails.env.development?
  # Validate memcache is running - on a first install on dev computer, you might not have memcache installed.
  CACHE = CacheWrapper.ensure_memcache_access
else
  CACHE = CacheWrapper.new(Rails.env=='test' ? TestExtensions::MockCache.new : CacheWrapper.get_production_client)
end

# Monkey Patches MonoLogger to set a default formatter that is the same as the rails one
# Needs to be done in here instead of in an initializer so the formatter is set for the 
# environments files (initializers are run after environment is loaded and the logger
# configuration really needs to be done right away)
class MonoLogger

  alias :old_initialize :initialize
  # Overwrite initialize to set a default formatter.
  def initialize(*args)
    old_initialize(*args)
    self.formatter = Logger::SimpleFormatter.new
  end
end

OpenChain::Application.initialize!

if Rails.env.development?
  # Ensure redis is running...otherwise many things will fail.  Only dev since that's the only environment where redis may actually not be there
  # (like on first time start-ups)
  Lock.ensure_redis_access
end

Mime::Type.register "application/vnd.ms-excel", :xls

if defined?(PhusionPassenger)
  PhusionPassenger.on_event(:starting_worker_process) do |forked|
    # Only works with DalliStore
    if forked
      CACHE.reset
    end
  end
end
