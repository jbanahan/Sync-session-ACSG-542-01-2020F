# Load the Rails application.
require File.expand_path('../application', __FILE__)

Dir.mkdir("log") unless Dir.exist?("log")
Dir.mkdir("tmp") unless Dir.exist?("tmp")

# This is required to allow New Relic access to Garbage Collection timings / statistics
GC::Profiler.enable

# Initialize the Rails application.
Rails.application.initialize!
