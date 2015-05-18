source 'https://rubygems.org'

gem 'rails', '3.2.21'
gem 'mysql2', '0.3.13'
gem 'sqlite3'
# AWS-SDK prior to 1.15 has a timeout bug in Ruby 2 on s3_object.write
gem 'aws-sdk', '1.17.0'
gem 'will_paginate', '3.0.4'
gem 'paperclip', '3.5.1'
gem 'uuidtools', '2.1.4'
gem 'spreadsheet', '0.8.8'
gem 'exception_notification', '4.0.0'
gem 'rufus-scheduler', '2.0.24'
gem 'delayed_job_active_record', '0.4.4'
gem 'delayed_job', '3.0.5'
# daemons is needed for the delayed job command line
gem 'daemons', '1.1.9'
gem 'dalli', '2.6.4'
gem 'postmark-rails', '0.5.2'
# rubyzip API changed in 1.0, need to pin to version prior to 1.0 until we fix files referencing 'zip/zip'
gem 'rubyzip', '< 1.0.0'
gem 'jquery-rails', '2.3.0'
gem 'newrelic_rpm', '~> 3.8.0.218'

#text processing/encoding stuff
gem 'RedCloth', '4.2.9'

#javascript environment, we will compile assets during deployment
#so we need these on the production servers as well
gem 'execjs', '2.0.1'
gem 'therubyracer', '0.12.0', :require => 'v8'
gem 'browser'

gem "google-api-client", "0.8.6"
gem "omniauth-google-oauth2", "0.2.2"
gem "omniauth-saml", "~> 1.2.0"

gem "cache_digests"

#async threaded processing
gem 'sucker_punch', '~> 1.0'

#faster asset:precompile
gem 'turbo-sprockets-rails3', '~> 0.3'

#inbound email processing
gem 'griddler', '~> 1.0'
gem 'griddler-postmark', '~> 1.0'

# Standard ruby logger uses mutexes for writing / rotation which we don't need and
# causes issues since Ruby 2.0 doesn't allow mutexes in signal traps - delayed_job specifically
# needs this.
gem "mono_logger", '1.1.0'
gem "net-sftp", '2.1.2'
gem "clearance", '1.3.0'

gem 'redis-semaphore', '~> 0.2'
gem 'redis-namespace', '~> 1.5'
gem 'connection_pool', '~> 2.1'

group :development,:test do
  gem 'rspec-rails', '~> 2.12'
  # gem 'rspec-prof', git: 'https://github.com/sinisterchipmunk/rspec-prof.git'
  gem 'factory_girl', '2.5.2'
  gem 'spork'
  gem 'byebug'
  gem 'jasmine-rails'
  gem 'rspec_junit_formatter', '0.2.2' #circle ci formatting
  # gem 'rack-mini-profiler'
end

group :test do
  gem 'mocha', '0.9.12', :require => false #http://blog.agoragames.com/2010/09/10/rails-3-mocha-load-order-gotcha/
  gem 'webmock'
end
# Gems used only for assets and not required
# in production environments by default.
group :assets do
  gem 'sass-rails', " ~> 3.2.3"
  gem 'coffee-rails', " ~> 3.2.1"
  gem 'uglifier'
end
