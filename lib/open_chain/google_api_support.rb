require 'google/apis/drive_v3'
require 'google/apis/admin_directory_v1'
require 'google/apis/appsactivity_v1'
require 'googleauth'

module OpenChain; module GoogleApiSupport
  extend ActiveSupport::Concern

  Google::Apis::ClientOptions.default.application_name = "VFI Track"
  Google::Apis::ClientOptions.default.application_version = '1.0.0'
  Google::Apis::RequestOptions.default.retries = 5

  SCOPES ||= [Google::Apis::DriveV3::AUTH_DRIVE, Google::Apis::AdminDirectoryV1::AUTH_ADMIN_DIRECTORY_USER_READONLY, Google::Apis::AppsactivityV1::AUTH_ACTIVITY]

  def default_google_account
    MasterSetup.production_env? ? "integration@vandegriftinc.com" : "integration-dev@vandegriftinc.com"
  end

  def account_credentials google_account:, scope:
    # The UserRefreshCredentials here are used to retrieve access_tokens from the google auth system.  They internally store state about the token and transparently fetch
    # new tokens whenever the old one expires. Credentials are NOT thread-safe.
    google_account = default_google_account() if google_account.blank?

    @credential_store ||= begin
      data = MasterSetup.secrets["google_authentication"]
      raise "You do not appear to have set up google authentication.  Please add authentication information to secrets.yml under 'google_authentication' key." if data.blank?
      store = {}
      data.each_pair do |email_account, data|
        # Symbolize the yaml keys - that's the way google likes them (one liner curtesy of https://gist.github.com/Integralist/9503099 )
        creds = data.reduce({}) { |memo, (k, v)| memo.merge({ k.to_sym => v}) }
        SCOPES.each do |default_scope|
          scope_creds = creds.dup
          scope_creds[:addtional_parameters] = {"access_type" => "offline"}
          # Should have client_id, client_secret, refresh_token and scope keys in the file
          store[default_scope] ||= {}
          store[default_scope][email_account] = Google::Auth::UserRefreshCredentials.new(scope_creds)
        end
      end
      store
    end

    scoped_credentials = @credential_store[scope]
    raise "No scope has been set up for #{scope}.  You must add this scope to the OpenChain::GoogleApiSupport::SCOPES array constant to be able to use it." if scoped_credentials.nil?
    credentials = scoped_credentials[google_account]
    raise "No user credentials appear to be configured for #{google_account}.  Check the 'google_authentication' credentials in secrets.yml." unless credentials

    credentials
  end

  def drive_service google_account_name: nil
    credentials = account_credentials(google_account: google_account_name, scope: Google::Apis::DriveV3::AUTH_DRIVE)

    drive = Google::Apis::DriveV3::DriveService.new
    drive.authorization = credentials
    drive
  end

  def admin_directory_service google_account_name: nil
    credentials = account_credentials(google_account: google_account_name, scope: Google::Apis::AdminDirectoryV1::AUTH_ADMIN_DIRECTORY_USER_READONLY)
    dir_service = Google::Apis::AdminDirectoryV1::DirectoryService.new
    dir_service.authorization = credentials

    dir_service
  end

  def activity_service google_account_name: nil
    credentials = account_credentials(google_account: google_account_name, scope: Google::Apis::AppsactivityV1::AUTH_ACTIVITY)

    activity = Google::Apis::AppsactivityV1::AppsactivityService.new
    activity.authorization = credentials
    activity
  end

  module ClassMethods

    # This method needs to be run any time any new Scope is being added to the SCOPES constant above.  It will generate
    # a new refresh token and output yaml configuration that should be placed under the "google_authentication" key in secrets.yml.
    #
    # The code can be run on any developer machine prior to deploying new features accessing new Google APIs.
    # It should NOT be run multiple times as there is only around 25 refresh tokens that are granted before some are revoked.
    #
    # If run too many times, it's possible you will invalidate the current production refresh token.
    def authorize_all_scopes account, token_file: "tmp/token.yml"
      require 'googleauth/stores/file_token_store'

      data = MasterSetup.secrets["google_authentication"]
      account_data = data[account]
      raise "No account data exists for #{account}." if account_data.nil?
      client_id = Google::Auth::ClientId.new account_data["client_id"], account_data["client_secret"]

      token_store = Google::Auth::Stores::FileTokenStore.new(file: token_file)
      authorizer = Google::Auth::UserAuthorizer.new(client_id, OpenChain::GoogleApiSupport::SCOPES, token_store)

      url = authorizer.get_authorization_url(base_url:'urn:ietf:wg:oauth:2.0:oob')
      puts "Open the following URL in a browser, log in as #{account} and authorize the VFI Track access to the given scopes.\nPaste the authorization code here when authorization is granted\n\n\n#{url}\n\n> "
      code = gets
      credentials = authorizer.get_and_store_credentials_from_code(user_id: account, code: code.strip, base_url: 'urn:ietf:wg:oauth:2.0:oob')

      token = token_store.load account
      raise "Failed to load stored credentials from 'tmp/token.yml'" if token.blank?

      token_data = JSON.parse token

      puts "\n\nAdd the following lines to 'secrets.yml' under the 'google_authentication' key, replacing any existing data for #{account} with the following:\n\n"
      config_output = {account => {"client_id" => client_id.id, "client_secret" => client_id.secret, "refresh_token" => token_data["refresh_token"]}}.to_yaml
      config_output = config_output[4..-1] if config_output.starts_with?("---\n")
      puts config_output

      puts "\n\nOnce you update the #{account} data in 'secrets.yml', you can delete the file named #{token_file}."

      nil
    end
  end

end; end