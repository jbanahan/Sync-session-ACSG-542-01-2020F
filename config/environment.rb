# Load the rails application
require File.expand_path('../application', __FILE__)
require 'open_chain/test_extensions'
require 'open_chain/cache_wrapper'
require 'mono_logger'

GC::Profiler.enable

# Initialize the rails application
CACHE = CacheWrapper.new(Rails.env=='test' ? TestExtensions::MockCache.new : CacheWrapper.get_production_client)

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

Mime::Type.register "application/vnd.ms-excel", :xls

if defined?(PhusionPassenger)
  PhusionPassenger.on_event(:starting_worker_process) do |forked|
    # Only works with DalliStore
    if forked
      CACHE.reset
    end
  end
end
