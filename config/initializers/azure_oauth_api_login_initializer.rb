config = MasterSetup.secrets["azure_oauth2"]
if config
  if !config['client_id'].blank? && !config['tenant_id'].blank? && !config['client_secret'].blank?
    Rails.application.config.azure_oauth2_api_login = {client_secret: config['client_secret'], tenant_id: config['tenant_id'], client_id: config['client_id']}
  end
end
