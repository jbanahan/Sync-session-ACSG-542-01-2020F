# If you ever need to test a server setup without SSL, you'll need to set this to false.
# Otherwise, it should be left alone.
Rails.application.config.use_secure_cookies = !Rails.env.development?