Rails.application.config.use_google_auth = false
Rails.application.config.use_azure_auth = false
Rails.application.config.disable_remember_me = false
Rails.application.config.pepsi_sso_url = nil

OmniAuth.config.failure_raise_out_environments = [:test]

# To get these settings, you need to log into the Google Developers console, choose the VFI Track
# project, open the credentials page and go to the OAuth 2.0 client IDs.  You will need to access or create
# credentials for a Web application.  Once created you can download the json file Google gives you,
# and extract the client_id and client_secret values from it and place those keys and values under a 
# 'google_oauth2' key in secrets.yml.
#
# NOTE: Client IDs are specific to EVERY deployment instance.  You cannot use the same client id
# for 'www' and for 'test' or a customer specific instance.
google_auth_settings = MasterSetup.secrets["google_oauth2"]

azure_auth_settings = MasterSetup.secrets['azure_oauth2']

if File.exist?("config/pepsi-idp-metadata.xml")
  # Pepsi's SSO SAML system does not appear to work like a "standard" system does.  All we need to do is include our SPID (Service Provider ID - pepsi.vfitrack.net) 
  # as a query parameter into the SSO link, rather than forwarding a full-fledged SAML AuthnRequest XML.  So, basically, the whole request_phase that the Omniauth-SAML 
  # gem provides is totally unused, only the callback is utilized (hence the reason why I'm killing it in the request_path below with a lambda always returning false).
  spid = "pepsi.vfitrack.net"
  idp_metadata_settings = OneLogin::RubySaml::IdpMetadataParser.new.parse_to_hash(IO.read("config/pepsi-idp-metadata.xml"))
end

return unless google_auth_settings || azure_auth_settings || idp_metadata_settings

Rails.application.config.middleware.use OmniAuth::Builder do
  if google_auth_settings
    # The client options below can be removed once we can upgrade the Google OAuth 2 gem...they're just overridind the default ones
    # from the old gem w/ the new ones
    provider(:google_oauth2, google_auth_settings["client_id"], google_auth_settings["client_secret"])  
    Rails.application.config.use_google_auth = true
  end
  
  if azure_auth_settings
    provider(:azure_oauth2, client_id: azure_auth_settings["client_id"], 
                            client_secret: azure_auth_settings["client_secret"], 
                            tenant_id: azure_auth_settings["tenant_id"])
    Rails.application.config.use_azure_auth = true
  end

  if idp_metadata_settings
    provider :saml,
      idp_metadata_settings.merge({
        :assertion_consumer_service_url     => "https://#{MasterSetup.get&.system_code}.vfitrack.net#{OmniAuth.config.path_prefix}/pepsi-saml/callback",
        :issuer                             => spid,
        :request_path                       => lambda {|env| return false },
        :callback_path                      => "#{OmniAuth.config.path_prefix}/pepsi-saml/callback"  
      })
    Rails.application.config.pepsi_sso_url = (idp_metadata_settings[:idp_sso_target_url] + "?SPID=#{spid}")
    Rails.application.config.disable_remember_me = true
  end
end  

