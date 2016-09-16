require 'google/api_client'

module OpenChain
  class GoogleAccountChecker
    def self.run_schedulable(opts={})
      self.new(opts).run
    end

    def initialize(settings={})
      @client = get_client
      @api = get_api
      @settings = settings
      @client.authorization.fetch_access_token!
    end

    def run
      User.where("email like '%vandegriftinc.com'").all.each do |user|
        email = user.email.gsub(/(.*?)(\+.*?)(@.*)/, '\1\3')
        body = @client.execute(@api.users.get, userKey: email).response.body
        body = JSON.parse(body)
        suspended = suspended?(body)
        user.update_attribute(:disabled, suspended) if suspended.present?
      end
    end

    private

    def suspended?(google_json)
      if google_json['error'].present? && google_json['error']['code'] == 404
        # If a 404 is raised, no user was found. Assuming that indicates they are suspended.
        true
      elsif google_json['error'].present? && google_json['error']['code'] == 400
        # A 400 error is thrown if a group account is looked up. We don't want anything to happen, in that case.
        nil
      elsif google_json['error'].present?
        raise(google_json['error']['message'])
      else
        google_json['suspended']
      end
    end

    def get_api
      @client.discovered_api("admin", "directory_v1")
    end

    def get_client
      environment = Rails.env
      user_email = environment == "production" ? "integration@vandegriftinc.com" : "integration-dev@vandegriftinc.com"
      auth_data = YAML::load_file('config/google_drive.yml')
      client = Google::APIClient.new(application_name: auth_data[environment]['application_name'],
                                     application_version: auth_data[environment]['application_version'],
                                     auto_refresh_token: true)

      client.authorization.client_id = auth_data[environment]['client_id']
      client.authorization.client_secret = auth_data[environment]['client_secret']
      client.authorization.scope = "https://www.googleapis.com/auth/admin.directory.user.readonly"
      client.authorization.redirect_uri = "urn:ietf:wg:oauth:2.0:oob"
      client.authorization.refresh_token = auth_data[user_email][environment]['refresh_token']
      client
    end
  end
end