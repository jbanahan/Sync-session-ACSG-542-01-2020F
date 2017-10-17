source 'https://rubygems.org'

gem "rails", "3.2.22"
gem 'mysql2', '0.3.21'
gem 'sqlite3'
gem 'aws-sdk', '~> 2.6'
# Handles AWS SNS posts
gem 'heroic-sns', '~> 1.1'
gem 'will_paginate', '3.0.4'
# AWS SDK V1 is ONLY needed for Paperclip - all of our code should be using v2
# Paperclip v5 added support for aws-sdk V2 - v5 only supports rails >= 4.2 (not the 3 series)
gem 'aws-sdk-v1', '~> 1.66'
gem 'paperclip', '3.5.1'
gem 'uuidtools', '2.1.4'
gem 'spreadsheet', '~> 1.0'
gem 'exception_notification', '4.0.0'
gem 'rufus-scheduler', '2.0.24'
gem 'delayed_job_active_record', '0.4.4'
gem 'delayed_job', '3.0.5'
# daemons is needed for the delayed job command line
gem 'daemons', '1.1.9'
gem 'dalli', '2.6.4'
gem 'postmark-rails', '0.5.2'
gem 'rubyzip', '~> 1.1'
gem 'jquery-rails', '2.3.0'
gem 'newrelic_rpm', '~> 3.16.0'

#text processing/encoding stuff
gem 'RedCloth', '4.2.9'

# PDF Generator
gem 'prawn', '2.0.2'
gem 'prawn-table', '0.2.2'
# Prawn doesn't support pdf templates, so use another lib to combine two pdfs together, one being the template the other the actual content
gem 'combine_pdf', '~> 0.2'
# Barcode Generator
gem 'barby', '~> 0.6'
# Required for generating Barcodes as PNG images
gem 'chunky_png', '~> 1.3.7'

#javascript environment, we will compile assets during deployment
#so we need these on the production servers as well
gem 'execjs', '2.0.1'
gem 'therubyracer', '0.12.0', :require => 'v8'
gem 'browser'

gem "google-api-client", :git => "https://github.com/Vandegrift/google-api-ruby-client"
gem "omniauth-google-oauth2", "0.5.2"
gem "omniauth-saml", "~> 1.2.0"

gem "cache_digests"

#async threaded processing
gem 'sucker_punch', '~> 1.0'

#faster asset:precompile
gem 'turbo-sprockets-rails3', '~> 0.3'

#inbound email processing
gem 'griddler', '~> 1.1'
gem 'griddler-postmark', '~> 1.0'

# Standard ruby logger uses mutexes for writing / rotation which we don't need and
# causes issues since Ruby 2.0 doesn't allow mutexes in signal traps - delayed_job specifically
# needs this.
gem "mono_logger", '1.1.0'
gem "net-sftp", '2.1.2'
# For some reason, our WingFTP server doesn't correctly terminate ssh connections for any version of net-ssh > 2.7.0..so this locks the version in place.
gem "net-ssh", '2.7.0' 
gem "clearance", '1.3.0'

gem 'connection_pool', '~> 2.2'
gem 'redlock', '~> 0.1'
gem 'concurrent-ruby', '~> 1.0'

gem 'jsonpath', '~> 0.5.6'
gem 'rgpg'

# Rails 3 requires test unit even in production (for some reason).  I believe in 4 this can be dropped to just the test group
gem 'test-unit'

# Slack.com integration
gem 'slack-ruby-client', '~> 0.10'

# Trello.com integration
gem 'ruby-trello', '1.3.0'

gem 'email_validator', '~> 1.6.0'

# EDI Processor
gem 'REX12', '~> 0.1.4'

group :development,:test do
  gem 'rspec-rails', '~> 3.5.0'
  # gem 'rspec-prof', git: 'https://github.com/sinisterchipmunk/rspec-prof.git'
  gem 'factory_girl', '2.5.2'
  gem 'byebug'
  gem 'jasmine-rails', '0.4.6'
  gem 'rspec_junit_formatter', '~> 0.2.3' #circle-ci formatting
  # gem 'rack-mini-profiler'
  gem 'minitest'
  gem 'active_record_query_trace'
end

group :test do
  gem 'mocha', '0.9.12', :require => false #http://blog.agoragames.com/2010/09/10/rails-3-mocha-load-order-gotcha/
  gem 'webmock'
  gem 'timecop', '~> 0.8.0'
end
# Gems used only for assets and not required
# in production environments by default.
group :assets do
  gem 'sass-rails', " ~> 3.2.3"
  gem 'coffee-rails', " ~> 3.2.1"
  gem 'uglifier'
end
