# Load the rails application
require File.expand_path('../application', __FILE__)

# Initialize the rails application
OpenChain::Application.initialize!

Mime::Type.register "application/vnd.ms-excel", :xls
