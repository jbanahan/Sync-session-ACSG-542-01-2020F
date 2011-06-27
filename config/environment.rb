# Load the rails application
require File.expand_path('../application', __FILE__)
require 'open_chain/test_extensions'

# Initialize the rails application
time_stamp = File.new('tmp/restart.txt').nil? ? Time.now : File.new('tmp/restart.txt').mtime
CACHE = Rails.env=='test' ? TestExtensions::MockCache.new : Dalli::Client.new(['localhost:11211'], {:namespace=>"#{time_stamp.to_i}#{Rails.root.basename}"})
OpenChain::Application.initialize!

Mime::Type.register "application/vnd.ms-excel", :xls
