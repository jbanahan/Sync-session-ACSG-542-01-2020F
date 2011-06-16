# Load the rails application
require File.expand_path('../application', __FILE__)

# Initialize the rails application
OpenChain::Application.initialize!

time_stamp = File.new('tmp/restart.txt').nil? ? Time.now : File.new('tmp/restart.txt').mtime
CACHE = Dalli::Client.new ['localhost:11211'], {:namespace=>"#{time_stamp.to_i}#{Rails.root.basename}"}
Mime::Type.register "application/vnd.ms-excel", :xls
