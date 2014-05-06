require 'uri'
require 'open_chain/json_http_client'

module OpenChain; module Api; class ApiClient

  attr_accessor :endpoint, :username, :authtoken

  VALID_ENDPOINTS ||= {
    "polo" => 'https://polo.chain.io',
    "vfitrack" => 'https://www.vfitrack.net',
    "ann" => 'https://ann.vfitrack.net',
    "underarmour" => 'https://underarmour.chain.io',
    'jcrew' => 'https://jcrew.vfitrack.net',
    "bdemo" => 'https://bdemo.chain.io',
    "das" => 'https://das.vfitrack.net',
    "warnaco" => 'https://warnaco.vfitrack.net',
    "dev" => "http://localhost:3000",
    "test" => "http://www.notadomain.com"
  }

  def initialize endpoint_alias, username, authtoken
    @endpoint = VALID_ENDPOINTS[endpoint_alias]
    raise ArgumentError, "#{endpoint_alias} is not a valid API endpoint." if @endpoint.blank?
    @username = username
    @authtoken = authtoken
  end

  def mf_uid_list_to_param uids
    uids.blank? ? {} : {"mf_uids" => uids.inject(""){|i, uid| i += "#{uid.to_s},"}[0..-2]}
  end

  def send_request path, parameters = {}
    path = path[1..-1] if path.starts_with? "/"

    uri_string = "#{endpoint}/api/v1/#{URI.encode(path)}"
    uri_string += "?#{encode_parameters(parameters)}" unless parameters.blank?
    authtoken = "#{username}:#{@authtoken}"

    uri = URI.parse(uri_string)
    retry_count = 0
    r = nil
    status = nil
    begin
      r = JsonHttpClient.new.get uri_string, {}, authtoken
    rescue => e
      # There's no real point in retrying 400 series errors, since they're all going to be issues in some manner with the 
      # client request.  The only one we want to specifically watch out for and raise differently is a 401, since that means authentication failed.
      if e.is_a? OpenChain::HttpErrorWithResponse
        http_status = e.http_status.to_i
        if http_status == 401
          raise ApiAuthenticationError.new((e.http_response_body ? e.http_response_body : make_errors_json("Access to API denied.")), endpoint, username, @authtoken)
        elsif (http_status / 100) == 4
          raise ApiError.new(e.http_response_body ? e.http_response_body : make_errors_json(e.message))
        elsif (http_status / 100) == 5
          # Retry 500 series errors a couple times, just in case
          retry_count += 1
          if retry_count < 3
            r = nil
            sleep 1
            retry
          end

          # Set the backtrace information to be that of the actual underlying error
          raise_api_error_from_error_response(e)
        else
          # This means we likely got a valid response but there was something wrong w/ the data (perhaps invalid json?) that caused an error
          raise_api_error_from_error_response(e)
        end
      else
        raise e
      end
    end

    r
  end

  def raise_api_error_from_error_response e
    api_error = ApiError.new(e.http_response_body ? e.http_response_body : make_errors_json("API Request failed with error: #{e.message}"))
    api_error.set_backtrace(e.backtrace)

    raise api_error
  end

  class ApiError < StandardError 
    attr_reader :response

    def initialize json_error
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

    def initialize json_error, api_endpoint, api_username, api_token
      @api_endpoint = api_endpoint
      @api_username = api_username
      @api_token = api_token
      super(json_error)
    end

    def message
     "Authentication to #{api_endpoint} failed for user '#{api_username}' and api token '#{api_token}'. Error: #{super}"
    end
  end

  private 

    def encode_parameters parameters
      parameters.map {|k, v| "#{CGI.escape(k)}=#{CGI.escape(v)}"}.join("&")
    end

    def make_errors_json errors
      r = {'errors'=>(errors.is_a?(Array) ? errors : [errors])}
    end

end; end; end