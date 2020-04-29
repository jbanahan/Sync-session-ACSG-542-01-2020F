require 'uri'
require 'open_chain/json_http_client'

module OpenChain; module Api; class ApiClient

  attr_accessor :endpoint, :username, :authtoken

  VALID_ENDPOINTS ||= {
    "polo" => 'https://polo.vfitrack.net',
    "vfitrack" => 'https://www.vfitrack.net',
    "ann" => 'https://ann.vfitrack.net',
    "underarmour" => 'https://underarmour.vfitrack.net',
    'jcrew' => 'https://jcrew.vfitrack.net',
    "bdemo" => 'https://bdemo.vfitrack.net',
    "das" => 'https://das.vfitrack.net',
    "ll"=> "https://ll.vfitrack.net",
    "vfitrack-test" => "https://test.vfitrack.net",
    "dev" => "http://0.0.0.0:3000",
    "test" => "http://www.notadomain.com"
  }

  def initialize endpoint_alias, username = nil, authtoken = nil
    endpoint_alias = self.class.substitute_endpoint(endpoint_alias)

    @endpoint = VALID_ENDPOINTS[endpoint_alias]
    raise ArgumentError, "#{endpoint_alias} is not a valid API endpoint." if @endpoint.blank?
    if username.blank? || authtoken.blank?
      @username, @authtoken = *self.class.default_username_authoken(endpoint_alias)
    else
      @username = username
      @authtoken = authtoken
    end
  end

  # This method exists solely to point all aliases at dev when run from dev system and not another system (unless overridden)
  def self.substitute_endpoint endpoint_alias
    if !MasterSetup.development_env?
      return endpoint_alias
    elsif MasterSetup.get.custom_feature?("Allow Production API Client in Dev")
      return endpoint_alias
    else
      return "dev"
    end
  end

  def self.valid_endpoint? endpoint_alias
    raise ArgumentError, "#{endpoint_alias} is not a valid API endpoint." if VALID_ENDPOINTS[endpoint_alias].blank?
    endpoint_alias
  end

  def self.default_username_authoken end_point
    config = get_config
    endpoint_alias = valid_endpoint? end_point
    user_authtoken = config[endpoint_alias]

    username = nil
    authtoken = nil

    if user_authtoken
      username = user_authtoken.keys.first
      authtoken = user_authtoken[username]
    end

    raise "No API Client configuration found for #{endpoint_alias}." if username.blank? || authtoken.blank?

    [username, authtoken]
  end

  def self.get_config
    MasterSetup.secrets.api_client
  end
  private_class_method :get_config

  def self.not_found_error? e
    e.is_a?(OpenChain::Api::ApiClient::ApiError) && e.http_status.to_s == "404"
  end

  def get path, parameters = {}
    uri_string = construct_path path
    uri_string += "?#{encode_parameters(parameters)}" unless parameters.blank?
    execute_request {|token| http_client.get uri_string, {}, token}
  end

  def delete path, parameters = {}
    uri_string = construct_path path
    uri_string += "?#{encode_parameters(parameters)}" unless parameters.blank?
    execute_request {|token| http_client.delete uri_string, {}, token}
  end

  def post path, request_body
    uri_string = construct_path path
    execute_request {|token| http_client.post uri_string, request_body, {}, token}
  end

  def put path, request_body
    uri_string = construct_path path
    execute_request {|token| http_client.put uri_string, request_body, {}, token}
  end

  def patch path, request_body
    uri_string = construct_path path
    execute_request {|token| http_client.patch uri_string, request_body, {}, token}
  end

  def raise_api_error_from_error_response http_status, e
    api_error = ApiError.new(http_status, e.http_response_body ? e.http_response_body : make_errors_json("API Request failed with error: #{e.message}"))
    api_error.set_backtrace(e.backtrace)

    raise api_error
  end

  class ApiError < StandardError
    attr_reader :response, :http_status

    def initialize http_status, json_error
      @http_status = http_status
      @response = json_error

      if json_error && json_error['errors']
        super(json_error['errors'].first)
      else
        super()
      end
    end
  end

  # Special subclass of the ApiError to help us identify/notify when we have authentication issues internally since this
  # is a case that needs to be resolved immediately.
  class ApiAuthenticationError < ApiError

    attr_reader :api_endpoint, :api_token, :api_username

    def initialize http_status, json_error, api_endpoint, api_username, api_token
      @api_endpoint = api_endpoint
      @api_username = api_username
      @api_token = api_token
      super(http_status, json_error)
    end

    def message
     "Authentication to #{api_endpoint} failed for user '#{api_username}' and api token '#{api_token}'. Error: #{super}"
    end
  end

  protected
    def execute_request
      request_authtoken = build_authtoken

      retry_count = 0
      r = nil
      status = nil
      begin
        r = yield request_authtoken
      rescue => e
        # There's no real point in retrying 400 series errors, since they're all going to be issues in some manner with the
        # client request.  The only one we want to specifically watch out for and raise differently is a 401, since that means authentication failed.
        if e.is_a? OpenChain::HttpErrorWithResponse
          http_status = e.http_status.to_i
          if http_status == 401
            raise ApiAuthenticationError.new(http_status, (e.http_response_body ? e.http_response_body : make_errors_json("Access to API denied.")), endpoint, username, authtoken)
          elsif (http_status / 100) == 4
            raise ApiError.new(http_status, e.http_response_body ? e.http_response_body : make_errors_json(e.message))
          elsif (http_status / 100) == 5
            # Retry 500 series errors a couple times, just in case
            retry_count += 1
            if retry_count < 3
              r = nil
              sleep 1
              retry
            end

            # Set the backtrace information to be that of the actual underlying error
            raise_api_error_from_error_response(http_status, e)
          else
            # This means we likely got a valid response but there was something wrong w/ the data (perhaps invalid json?) that caused an error
            raise_api_error_from_error_response(http_status, e)
          end
        else
          raise e
        end
      end

      r
    end

  private
    def construct_path path
      path = path[1..-1] if path.starts_with? "/"

      uri_string = "#{endpoint}/api/v1/#{URI.encode(path)}"
    end

    def build_authtoken
      "#{username}:#{authtoken}"
    end

    def encode_parameters parameters
      parameters.map {|k, v| "#{CGI.escape(k.to_s)}=#{CGI.escape(v)}"}.join("&")
    end

    def make_errors_json errors
      r = {'errors'=>(errors.is_a?(Array) ? errors : [errors])}
    end

    def http_client
      JsonHttpClient.new
    end

end; end; end
