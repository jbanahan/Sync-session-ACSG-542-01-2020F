if File.exist?("config/vfitrack_settings.yml")
  Rails.application.config.vfitrack_settings = Rails.application.config_for(:vfitrack_settings)
end
