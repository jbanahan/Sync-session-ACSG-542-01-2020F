require 'google/apis/drive_v3'
require 'google/apis/admin_directory_v1'
require 'googleauth'

module OpenChain; module GoogleApiSupport
  extend ActiveSupport::Concern

  Google::Apis::ClientOptions.default.application_name = "VFI Track"
  Google::Apis::ClientOptions.default.application_version = '1.0.0'
  Google::Apis::RequestOptions.default.retries = 5

  SCOPES = [Google::Apis::DriveV3::AUTH_DRIVE, Google::Apis::AdminDirectoryV1::AUTH_ADMIN_DIRECTORY_USER_READONLY]

  def default_google_account
    Rails.env.production? ? "integration@vandegriftinc.com" : "integration-dev@vandegriftinc.com"
  end

  def account_credentials google_account:, scope:, credentials_file: "config/google_api.yml"
    # The UserRefreshCredentials here are used to retrieve access_tokens from the google auth system.  They internally store state about the token and transparently fetch
    # new tokens whenever the old one expires. Credentials are NOT thread-safe.
    google_account = default_google_account() if google_account.blank?

    @credential_store ||= begin
      data = YAML::load_file(credentials_file)
      store = {}
      data.each_pair do |email_account, data|
        # Symbolize the yaml keys - that's the way google likes them (one liner curtesy of https://gist.github.com/Integralist/9503099 ) 
        creds = data.reduce({}) { |memo, (k, v)| memo.merge({ k.to_sym => v}) }
        SCOPES.each do |default_scope|
          scope_creds = creds.dup
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
    raise "No user credentials appear to be configured for #{google_account}.  Check the credentials in #{credentials_file}." unless credentials

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

end; end