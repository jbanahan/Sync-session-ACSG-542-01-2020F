require 'open_chain/http_client'

module OpenChain; class JsonHttpClient < HttpClient

  JSON_MIME ||= "application/json".freeze

  attr_accessor :authorization_token

  def initialize authorization_token: nil
    @authorization_token = authorization_token
  end

  protected

    def before_request_send _uri, request, headers: {}, connection_options: {} # rubocop:disable Lint/UnusedMethodArgument
      headers["Accept"] = JSON_MIME
      headers["Content-Type"] = JSON_MIME
      if request.respond_to?(:body) && !request.body.is_a?(String)
        request.body = request.body.to_json
      end

      if authorization_token.present?
        headers["Authorization"] = "Token token=\"#{authorization_token}\""
      end

      nil
    end

    def process_response response
      if json_response? response
        r = response.body.blank? ? {} : JSON.parse(response.body)
      else
        raise "Expected to receive JSON response, received '#{response['content-type'].to_s}' instead."
      end
    end

  private

    def json_response? response
      response['content-type'].to_s.include? JSON_MIME
    end

end; end