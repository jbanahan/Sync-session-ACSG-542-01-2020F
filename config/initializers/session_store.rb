# Be sure to restart your server when you modify this file.

OpenChain::Application.config.session_store :cookie_store, :key => '_OpenChain_session', :secure => Rails.application.config.use_secure_cookies, :httponly => true

# Use the database for sessions instead of the cookie-based default,
# which shouldn't be used to store highly confidential information
# (create the session table with "rake db:sessions:create")
# OpenChain::Application.config.session_store :active_record_store
