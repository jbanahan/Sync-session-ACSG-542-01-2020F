# Load the rails application
require File.expand_path('../application', __FILE__)
require 'open_chain/test_extensions'
require 'open_chain/cache_wrapper'

GC::Profiler.enable

# Initialize the rails application
AWS_CREDENTIALS = YAML::load_file 'config/s3.yml'
FOG_S3 = {:aws_access_key_id=>AWS_CREDENTIALS['access_key_id'],
      :aws_secret_access_key=>AWS_CREDENTIALS['secret_access_key'],
      :provider=>'AWS'
      }

CACHE = CacheWrapper.new(Rails.env=='test' ? TestExtensions::MockCache.new : CacheWrapper.get_production_client)
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
