Rails.application.config.use_google_auth = false
Rails.application.config.disable_remember_me = false
Rails.application.config.pepsi_sso_url = nil

OmniAuth.config.failure_raise_out_environments = [:test]

if File.exist?("config/google_auth.json")
  google_auth_settings = JSON.parse(File.read("config/google_auth.json"))
  Rails.application.config.middleware.use OmniAuth::Builder do
    provider :google_oauth2, google_auth_settings["web"]["client_id"], google_auth_settings["web"]["client_secret"]
  end
  Rails.application.config.use_google_auth = true
end

if File.exist?("config/pepsi-idp-metadata.xml") && MasterSetup.get.custom_feature?("Pepsi SSO")
  spid = "pepsi.vfitrack.net"

  idp_metadata_settings = OneLogin::RubySaml::IdpMetadataParser.new.parse_to_hash(IO.read("config/pepsi-idp-metadata.xml"))

  # Pepsi's SSO SAML system does not appear to work like a "standard" system does.  All we need to do is include our SPID (Service Provider ID - pepsi.vfitrack.net) 
  # as a query parameter into the SSO link, rather than forwarding a full-fledged SAML AuthnRequest XML.  So, basically, the whole request_phase that the Omniauth-SAML 
  # gem provides is totally unused, only the callback is utilized (hence the reason why I'm killing it in the request_path below with a lambda always returning false).
  Rails.application.config.middleware.use OmniAuth::Builder do
    provider :saml,
      idp_metadata_settings.merge({
        :assertion_consumer_service_url     => "https://#{MasterSetup.get.system_code}.vfitrack.net#{OmniAuth.config.path_prefix}/pepsi-saml/callback",
        :issuer                             => spid,
        :request_path                       => lambda {|env| return false },
        :callback_path                      => "#{OmniAuth.config.path_prefix}/pepsi-saml/callback"  
      })
  end
  Rails.application.config.pepsi_sso_url = (idp_metadata_settings[:idp_sso_target_url] + "?SPID=#{spid}")
  Rails.application.config.disable_remember_me = true
end

