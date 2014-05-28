if ::USE_GOOGLE_AUTH
  Rails.application.config.middleware.use OmniAuth::Builder do
    provider :google_oauth2, ::GOOGLE_CLIENT_KEY, ::GOOGLE_SECRET_KEY
  end
end