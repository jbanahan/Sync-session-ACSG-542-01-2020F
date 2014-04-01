require 'uri'

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

    uri = URI.parse(uri_string)
    retry_count = 0
    r = nil
    status = nil
    begin
      res = Net::HTTP.start(uri.host, uri.port) do |http|
        if uri.scheme == "https"
          http.use_ssl = true
          http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        end
        
        req = Net::HTTP::Get.new(uri)
        req["Authorization"] = "Token token=\"#{username}:#{authtoken}\""
        req["Accept"] = "application/json"
        req["Host"] = uri.host

        http.read_timeout = 600
        http.request req
      end
      
      status = res.code
      # All errors from the API SHOULD have some form of JSON response so we should technically be able to parse 
      # every valid HTTP response..this won't apply to routing errors, which will return 404 HTML.  We should figure
      # out how to fix this before publically releasing the API, but I'm not 100% sure how at the moment.
      if json_response? res
        response_body = get_response_body res
        r = JSON.parse(response_body) unless response_body.blank?
      end
  
      raise "Server responded with an error: #{status}" unless status == "200"
    rescue => e
      # There's no real point in retrying 400 series errors, since they're all going to be issues in some manner with the 
      # client request.  The only one we want to specifically watch out for and raise differently is a 401, since that means authentication failed.
      
      if status
        if status == "401"
          raise ApiAuthenticationError.new((r ? r : make_errors_json("Access to API denied.")), endpoint, username, authtoken)
        elsif status.starts_with? "4"
          raise ApiError.new(r ? r : make_errors_json(e.message))
        end
      end

      retry_count += 1
      if retry_count < 3
        r = nil
        status = nil
        sleep 1
        retry
      end

      # Set the backtrace information to be that of the actual underlying error.
      api_error = ApiError.new(r ? r : make_errors_json("API Request failed with error: #{e.message}"))
      api_error.set_backtrace(e.backtrace)

      raise api_error
    end
    r
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
      "Authentication to #{api_endpoint} failed for user #{api_username} and #{api_token}: #{super}"
    end
  end


  private 

    def get_response_body response
      # This is a fix for the absolutely moronic implementation detail of Net::HTTP not setting the response body
      # charset based on the server's content-type response header.

      content_type = response['content-type']
      if content_type && content_type['charset']
        # Split the content_type header on ; (ie. header field separator) -> Content-Type: text/html; charset=UTF-8
        charset = content_type.split(';').select do |key|
          # Find the header key value that contains a charset
          key['charset']
        end

        # Only use the first charset (technically, there's nothing preventing multiple of them from being supplied in the header)
        # and split it into a key value pair array
        charset = charset.first.to_s.split("=")
        if charset.length == 2
          # If the server supplies an invalid or unsupported charset, we'll just handle the error and ignore it.
          # This isn't really any worse than what was happening before where the default charset was utilized.
          response.body.force_encoding(charset.last.strip) rescue ArgumentError
        end
      end

      response.body
    end

    def encode_parameters parameters
      parameters.map {|k, v| "#{CGI.escape(k)}=#{CGI.escape(v)}"}.join("&")
    end

    def make_errors_json errors
      r = {'errors'=>(errors.is_a?(Array) ? errors : [errors])}
    end

    def json_response? response
      response['content-type'].to_s.include? 'application/json'
    end

end; end; end