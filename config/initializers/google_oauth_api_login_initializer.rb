if File.exist?("config/google_oauth2_api_login.json")
  config = JSON.parse(File.read("config/google_oauth2_api_login.json"))
  if !config['installed'].blank? && !config['installed']['client_secret'].blank? && !config['installed']['client_id'].blank?
    Rails.application.config.google_oauth2_api_login = {client_secret: config['installed']['client_secret'], client_id: config['installed']['client_id']}
  end
end