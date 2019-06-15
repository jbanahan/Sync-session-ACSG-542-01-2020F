# Don't load this in test...we don't need it and we don't supply a default config for it.
if !MasterSetup.test_env?
  Recaptcha.configure do |config|
    # This file is required to be present as it protects the login page's registration request..if it bombs, we want the system to bomb
    recaptcha = MasterSetup.secrets["recaptcha"]

    config.site_key  = recaptcha['site_key']
    config.secret_key = recaptcha['secret_key']
  end
end