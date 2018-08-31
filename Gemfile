source 'https://rubygems.org'

gem "rails", git: "https://github.com/rails/rails.git", branch: "3-2-stable"
gem 'mysql2', '0.3.21'
gem 'sqlite3'
gem 'aws-sdk', '~> 2.6'
# Handles AWS SNS posts
gem 'heroic-sns', '~> 1.1'
gem 'will_paginate', '3.1.6'
# AWS SDK V1 is ONLY needed for Paperclip - all of our code should be using v2
# Paperclip v5 added support for aws-sdk V2 - v5 only supports rails >= 4.2 (not the 3 series)
gem 'aws-sdk-v1', '~> 1.66'
gem 'paperclip', '4.3.7'
gem 'uuidtools', '2.1.4'
gem 'spreadsheet', '1.1.5'
gem 'axlsx', '3.0.0.pre' # TODO: Unpin when a non-pre version without the ruby-zip vuln is released
gem 'axlsx_rails', '0.5.2'
gem 'exception_notification', '4.0.0'
gem 'rufus-scheduler', '3.5.0'
# The fugit gem is what rufus now uses behind the scenes for all the date/time/cron parsing stuff
# Figured we'd also just use it directly to handle cron / duration handling too.
gem 'fugit', '1.1.1'
gem 'delayed_job_active_record', '4.1.3'
gem 'delayed_job', '4.1.5'
# daemons is needed for the delayed job command line
gem 'daemons', '1.1.9'
gem 'dalli', '2.6.4'
gem 'dalli-elasticache', '~> 0.2'
gem 'postmark-rails', '0.5.2'
gem 'rubyzip', '~> 1.1'
gem 'jquery-rails', '~> 3.1.3'
gem 'newrelic_rpm', '~> 5.2.0'

#text processing/encoding stuff
gem 'RedCloth', '4.2.9'

# PDF Generator
gem 'prawn', '2.2.2'
gem 'prawn-table', '0.2.2'
# Prawn doesn't support pdf templates, so use another lib to combine two pdfs together, one being the template the other the actual content
gem 'combine_pdf', '~> 0.2'
# Barcode Generator
gem 'barby', '~> 0.6'
# Required for generating Barcodes as PNG images
gem 'chunky_png', '~> 1.3.10'

#javascript environment, we will compile assets during deployment
#so we need these on the production servers as well
gem 'execjs', '2.7.0'
gem 'mini_racer', '0.1.15'
gem 'browser'

gem "google-api-client", :git => "https://github.com/Vandegrift/google-api-ruby-client"
# LRU Redux provides an LRU (optionally timebased) cache...it's used to cache google drive paths
gem 'lru_redux', '~> 1.1.0'
gem "omniauth-google-oauth2", "0.5.3"
gem "omniauth-saml", "1.10.1"

gem "cache_digests"

gem 'concurrent-ruby', '~> 1.0'

#faster asset:precompile
gem 'turbo-sprockets-rails3', '~> 0.3'

#inbound email processing
gem 'griddler', '~> 1.1'
gem 'griddler-postmark', '~> 1.0'

# Standard ruby logger uses mutexes for writing / rotation which we don't need and
# causes issues since Ruby 2.0 doesn't allow mutexes in signal traps - delayed_job specifically needs this.
gem "mono_logger", '1.1.0'
gem "net-sftp", '2.1.2'
# Can update to net-ssh 5 when we're using a Ruby version > 2.2.5
gem "net-ssh", '4.2.0' 
gem "clearance", '1.3.0'

gem 'connection_pool', '~> 2.2'
gem 'redlock', '~> 0.2'

gem 'jsonpath', '~> 0.5.6'

# Rails 3 requires test unit even in production (for some reason).  I believe in 4 this can be dropped to just the test group
gem 'test-unit'

# Slack.com integration
gem 'slack-ruby-client', '~> 0.10'

# Trello.com integration
gem 'ruby-trello', '1.3.0'

gem 'email_validator', '~> 1.6.0'

# EDI Processor
gem 'REX12', '~> 0.2'

# Fix for links not working in the Microsoft Suite
gem 'fix_microsoft_links'

# Provides bulk SQL import statements
gem "activerecord-import"

group :development,:test do
  gem 'rspec-rails', '~> 3.5.0'
  # gem 'rspec-prof', git: 'https://github.com/sinisterchipmunk/rspec-prof.git'
  gem 'factory_girl', '2.5.2'
  gem 'byebug'
  gem 'jasmine-rails', '0.14.7'
  gem 'rspec_junit_formatter', '~> 0.2.3' #circle-ci formatting
  # gem 'rack-mini-profiler'
  gem 'minitest'
  gem 'active_record_query_trace'
  gem 'database_cleaner'
  gem 'annotate'
  # This is here exclusively so we can validate the xlsx files we produce.  
  # axlsx, while being a FAR more complete and better gem for writing xlsx files, cannot
  # read them.  So we need to use a different solution for reading them in test cases.
  gem 'rubyXL', '3.3.29'
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
