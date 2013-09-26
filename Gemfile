source 'http://rubygems.org'

gem 'rails', '3.2.12'
gem 'mysql2', '0.3.11'
gem 'mongrel', '1.2.0.pre2'
gem 'sqlite3'
gem 'fog'
gem 'aws-sdk'
gem 'authlogic', '3.0.3'
gem 'meta_search', '1.1.3'
gem 'will_paginate', '3.0.3'
gem 'paperclip', '2.4.5'
gem 'uuidtools', '2.1.0'
gem 'spreadsheet', '0.6.5.9'
gem 'exception_notification_rails3', :require => 'exception_notifier'
gem 'rufus-scheduler', '2.0.8'
gem 'delayed_job_active_record', '0.4.4'
gem 'delayed_job', '3.0.5'
gem 'dalli', '2.2.1'
gem 'postmark-rails', '0.4.1'
gem 'rubyzip'
gem 'jquery-rails'
gem 'newrelic_rpm', '3.6.5.130'

#text processing/encoding stuff
gem 'RedCloth', '4.2.9'

#javascript environment, we will compile assets during deployment
#so we need these on the production servers as well
gem 'execjs' 
gem 'libv8', '~> 3.11.8'
gem 'therubyracer'
gem 'browser'
gem "google-api-client", "0.6.4"

group :development,:test do

  gem 'rspec-rails'
  gem 'factory_girl', '2.5.2', :group=>[:development,:test]
  gem 'spork'
  gem 'debugger'
end

group :test do
  gem 'mocha', '0.9.12', :require => false #http://blog.agoragames.com/2010/09/10/rails-3-mocha-load-order-gotcha/
end
# Gems used only for assets and not required
# in production environments by default.
group :assets do
  gem 'sass-rails', " ~> 3.2.3"
  gem 'coffee-rails', " ~> 3.2.1"
  gem 'uglifier'
end

