if File.exist?("config/google_auth.json")
  Rails.application.config.use_google_auth = true
  google_auth_settings = JSON.parse(File.read("config/google_auth.json"))
  Rails.application.config.middleware.use OmniAuth::Builder do
    provider :google_oauth2, google_auth_settings["web"]["client_email"].split("@").first, google_auth_settings["web"]["client_secret"]
  end
else
  Rails.application.config.use_google_auth = false
end