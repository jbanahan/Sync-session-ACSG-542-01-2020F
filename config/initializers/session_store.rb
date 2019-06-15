# Be sure to restart your server when you modify this file.

OpenChain::Application.config.session_store :cookie_store, :key => '_OpenChain_session', :secure => Rails.application.config.use_secure_cookies, :httponly => true