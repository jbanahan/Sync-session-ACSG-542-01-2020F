Rails.application.config.use_google_auth = false
Rails.application.config.disable_remember_me = false
Rails.application.config.pepsi_sso_url = nil

OmniAuth.config.failure_raise_out_environments = [:test]

if File.exist?("config/google_auth.json")
  google_auth_settings = JSON.parse(File.read("config/google_auth.json"))

  # This is a simple monkey patch for the Google Auth2 provider...the provider was using a Google+ authentication channel (I think at the time 
  # it was the only one available).  When Google killed Google+, the gem switched to the different oauth endpoint, but in doing so they
  # also updated the JWT gemspec dependency to rely on JWT 2, which would force us to have to update a whole host of other gems simply
  # to use a different Google OAuth2 endpoint.  This is easier...we'll eventaully get around to upgrading the gem.  At that point, this can be removed.

  module OmniAuth; module Strategies; class GoogleOauth2 < OmniAuth::Strategies::OAuth2

    # This copy/pasted basically straight from GoogleOauth2...the only real change is to support multiple iss URLs.
    extra do
      hash = {}
      hash[:id_token] = access_token['id_token']
      if !options[:skip_jwt] && !access_token['id_token'].nil?
        hash[:id_info] = ::JWT.decode(
          access_token['id_token'], nil, false, verify_iss: options.verify_iss,
                                                iss: ['https://accounts.google.com', 'accounts.google.com'],
                                                verify_aud: true,
                                                aud: options.client_id,
                                                verify_sub: false,
                                                verify_expiration: true,
                                                verify_not_before: true,
                                                verify_iat: true,
                                                verify_jti: false,
                                                leeway: options[:jwt_leeway]
        ).first
      end
      hash[:raw_info] = raw_info unless skip_info?
      prune! hash
    end

    def raw_info
      @raw_info ||= access_token.get('https://www.googleapis.com/oauth2/v3/userinfo').parsed
    end

  end; end; end

  # This patch is to allow the verify_iss validation to support multiple iss URLs
  module JWT; class Verify
    def verify_iss
      valid_iss = @options.values_at(:iss, "iss").flatten.compact
      return if valid_iss.length == 0

      if !valid_iss.include? @payload['iss'].to_s
        raise(
          JWT::InvalidIssuerError,
          "Invalid issuer. Expected #{options_iss}, received #{@payload['iss'] || '<none>'}"
        )
      end
    end
  end; end

  Rails.application.config.middleware.use OmniAuth::Builder do
    # The client options below can be removed once we can upgrade the Google OAuth 2 gem...they're just overridind the default ones
    # from the old gem w/ the new ones
    provider(:google_oauth2, google_auth_settings["web"]["client_id"], google_auth_settings["web"]["client_secret"], {
      client_options: {
        site: 'https://oauth2.googleapis.com',
         authorize_url: 'https://accounts.google.com/o/oauth2/auth',
         token_url: '/token'
       }
    })
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

