Rails.application.config.use_google_auth = false
Rails.application.config.disable_remember_me = false
Rails.application.config.pepsi_sso_url = nil

if File.exist?("config/google_auth.json")
  google_auth_settings = JSON.parse(File.read("config/google_auth.json"))
  Rails.application.config.middleware.use OmniAuth::Builder do
    provider :google_oauth2, google_auth_settings["web"]["client_email"].split("@").first, google_auth_settings["web"]["client_secret"]
  end
  Rails.application.config.use_google_auth = true
end

if File.exist?("config/pepsi.pem")
  spid = "pepsi.vfitrack.net"
  saml_target = (Rails.env.production? ? "https://affiliateportal.mypepsico.com/affwebservices/public/saml2sso" : "https://affiliateportal.ite.mypepsico.com/affwebservices/public/saml2sso")
  # Pepsi's SSO SAML system does not appear to work like a "standard" system does.  All we need to do is include our SPID (Service Provider ID - pepsi.vfitrack.net) 
  # as a query parameter into the SSO link, rather than forwarding a full-fledged SAML AuthnRequest XML.  So, basically, the whole request_phase that the Omniauth-SAML 
  # gem provides is totally unused, only the callback is utilized (hence the reason why I'm killing it in the request_path below with a lambda always returning false).
  Rails.application.config.middleware.use OmniAuth::Builder do
    provider :saml,
      :assertion_consumer_service_url     => (Rails.env.production? ? "https://pepsi.vfitrack.net#{OmniAuth.config.path_prefix}/pepsi-saml/callback" : "http://development.vfitrack.net#{OmniAuth.config.path_prefix}/pepsi-saml/callback"),
      :issuer                             => spid,
      :idp_sso_target_url                 => saml_target,
      :idp_cert                           => IO.read("config/pepsi.pem"),
      :name_identifier_format             => "urn:oasis:names:tc:SAML:1.1:nameid-format:unspecified",
      :request_path                       => lambda {|env| return false },
      :callback_path                      => "#{OmniAuth.config.path_prefix}/pepsi-saml/callback"
  end
  Rails.application.config.pepsi_sso_url = (saml_target + "?SPID=#{spid}")
  Rails.application.config.disable_remember_me = true
end

