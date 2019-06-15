if !MasterSetup.secrets["slack"].blank?
  token = MasterSetup.secrets["slack"].try(:[], "api_key")
  raise "Invalid 'slack' configuration in secrets.yml.  Make sure an 'api_key' is present below the slack key." if token.blank?
  Slack.configure do |config|
    config.token = token
  end
end