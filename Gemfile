source 'https://rubygems.org'

# BEGIN Rails Default gems
gem "rails", "5.0.7.2"
# Use SCSS for stylesheets
gem 'sass-rails', "6.0.0"
# Use Uglifier as compressor for JavaScript assets
gem 'uglifier', "4.2.0"
# Use CoffeeScript for .coffee assets and views
gem 'coffee-rails', "4.2.2"
# Use jquery as the JavaScript library
gem 'jquery-rails', '4.3.3'
# END RAILS DEFAULT GEMS

# AWS gems - only utilize gems required for specific services referenced by the project
gem 'aws-sdk-ec2', '1.212.0'
gem 'aws-sdk-ssm', '1.98.0'
gem 'aws-sdk-rds', '1.106.0'
gem 'aws-sdk-sqs', '1.34.0'
gem 'aws-sdk-s3', '1.85.0'
gem 'aws-sdk-cloudwatch', '1.46.0'

gem 'jquery-ui-rails', '6.0.1'
gem 'mysql2', '0.5.3'
gem 'will_paginate', '3.3.0'
gem 'paperclip', '6.1.0'
gem 'uuidtools', '2.1.4'
gem 'spreadsheet', '1.2.6'
gem 'caxlsx', '3.0.2'
gem 'caxlsx_rails', '0.6.2'
gem 'exception_notification', '4.4.3'
gem 'rufus-scheduler', '3.6.0'
# The fugit gem is what rufus now uses behind the scenes for all the date/time/cron parsing stuff
# Figured we'd also just use it directly to handle cron / duration handling too.
gem 'fugit', '1.4.1'
gem 'delayed_job_active_record', '4.1.4'
gem 'delayed_job', '4.1.8'
# daemons is needed for the delayed job command line
gem 'daemons', '1.3.1'
gem 'dalli', '2.7.11'
gem 'dalli-elasticache', '~> 0.2'
gem 'postmark-rails', '0.20.0'
gem 'rubyzip', '2.3.0'

gem 'newrelic_rpm', '~> 6.14.0'

# text processing/encoding stuff
gem 'RedCloth', '4.3.2'

# PDF Generator
gem 'prawn', '2.3.0'
gem 'prawn-table', '0.2.2'
# Prawn doesn't support pdf templates, so use another lib to combine two pdfs together, one being the template the other the actual content
gem 'combine_pdf', '~> 1.0.0'
# Barcode Generator
gem 'barby', '~> 0.6'
# Required for generating Barcodes as PNG images
gem 'chunky_png', '~> 1.3.10'

# javascript environment, we will compile assets during deployment
# so we need these on the production servers as well
gem 'execjs', '2.7.0'
gem 'mini_racer', '0.3.1'
gem 'browser', '2.5.3'

gem "google-api-client", "0.28.4"
# LRU Redux provides an LRU (optionally timebased) cache...it's used to cache google drive paths
gem 'lru_redux', '~> 1.1.0'
gem "omniauth-google-oauth2", '0.6.0'
gem "omniauth-saml", '1.10.1'
gem 'omniauth-azure-oauth2', '~> 0.0.10'
gem 'omniauth-rails_csrf_protection', '~> 0.1.2'
gem 'concurrent-ruby', '1.1.7'

# Standard ruby logger uses mutexes for writing / rotation which we don't need and
# causes issues since Ruby 2.0 doesn't allow mutexes in signal traps - delayed_job specifically needs this.
gem "mono_logger", '1.1.0'
gem "net-sftp", '3.0.0'
# Can update to net-ssh 5 when we're using a Ruby version > 2.2.5
gem "net-ssh", '6.1.0'
gem "clearance", '1.16.1'

gem 'connection_pool', '2.2.3'
gem 'redlock', '1.2.0'

gem 'jsonpath', '1.0.6'

# Slack.com integration
gem 'slack-ruby-client', '0.13.1'

gem 'email_validator', '1.6.0'

# Templating language for secure user input
gem 'liquid', '4.0.3'

# EDI Processor
gem 'REX12', '~> 0.2'

# Fix for links not working in the Microsoft Suite
gem 'fix_microsoft_links', '0.1.6'

# Provides bulk SQL import statements
gem "activerecord-import", '1.0.0'

# Seemlessly retries deadlocks / lock waits
gem 'transaction_retry', '1.0.3'

# Distribute database reads across replicas
gem "distribute_reads", '0.3.3'

# Google reCaptcha support
gem "recaptcha", '~> 4.13.1'

gem 'dry-core', '0.4.10'

gem 'brillo'

gem 'faker'

gem 'clamby'

gem 'fuzzy_match'

gem 'get_process_mem', '0.2.7'

gem 'nonschema_migrations', '2.0.1'

gem 'nokogiri', '1.10.10'

gem 'content_disposition', '1.0.0'

# Allows CSS stylesheets with emails.
gem 'premailer-rails'

gem 'dotenv-rails', '2.7.6'

group :development, :test do
  gem 'byebug'
  # This is here exclusively so we can validate the xlsx files we produce.
  # axlsx, while being a FAR more complete and better gem for writing xlsx files, cannot
  # read them.  So we need to use a different solution for reading them in test cases.
  gem 'rubyXL', '3.4.16'
  gem 'jasmine'
  gem 'brakeman'
  gem 'rubocop', '0.81.0', require: false
  gem 'rubocop-rails', '2.5.1', require: false
  gem 'rubocop-rspec', '1.38.1', require: false
end

group :development do
  # gem 'rack-mini-profiler'
  gem 'active_record_query_trace'
  gem 'annotate'
  gem 'web-console'
end

group :test do
  gem 'rspec-rails', '4.0.1'
  # gem 'rspec-prof', git: 'https://github.com/sinisterchipmunk/rspec-prof.git'
  gem 'factory_bot', '6.1.0'
  gem 'rspec_junit_formatter', '~> 0.4.1' # circle-ci formatting
  gem 'test-unit'
  gem 'webmock'
  gem 'timecop', '~> 0.9.0'
  gem 'database_cleaner'
end
