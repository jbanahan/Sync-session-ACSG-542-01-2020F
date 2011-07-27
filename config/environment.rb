# Load the rails application
require File.expand_path('../application', __FILE__)
require 'open_chain/test_extensions'
require 'open_chain/cache_wrapper'

# Initialize the rails application
yaml_file_path = "/config/memcached.yml"
CACHE = CacheWrapper.new(Rails.env=='test' ? TestExtensions::MockCache.new : CacheWrapper.get_production_client(yaml_file_path))
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

AWS.config(YAML.load(File.read('config/s3.yml'))[Rails.env.to_s])
