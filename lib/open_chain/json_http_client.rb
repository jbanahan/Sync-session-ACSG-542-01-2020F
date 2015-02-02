require 'open_chain/http_client'

module OpenChain; class JsonHttpClient < HttpClient

  JSON_MIME ||= "application/json".freeze

  def get url, additional_headers = {}, authorization_token = nil
    do_request_without_body(:get, url, additional_headers, authorization_token)
  end

  def post url, request_body, additional_headers = {}, authorization_token = nil
    do_request_with_body :post, url, request_body, additional_headers, authorization_token
  end

  def put url, request_body, additional_headers, authorization_token
    do_request_with_body :put, url, request_body, additional_headers, authorization_token
  end

  def patch url, request_body, additional_headers, authorization_token
    do_request_with_body :patch, url, request_body, additional_headers, authorization_token
  end

  def delete url, additional_headers = {}, authorization_token = nil
    do_request_without_body(:delete, url, additional_headers, authorization_token)
  end

  def send_request uri, request_method, additional_headers = {}, authorization_token = nil
    headers = {"Accept" => JSON_MIME}
    unless authorization_token.blank?
      headers["Authorization"] = "Token token=\"#{authorization_token}\""
    end
    headers = headers.merge additional_headers

    http_request(uri, request_method, headers.merge(additional_headers))
  end

  def process_response response
    if json_response? response
      r = response.body.blank? ? {} : JSON.parse(response.body)
    else
      raise "Expected to receive JSON response, received '#{response['content-type'].to_s}' instead."
    end
  end

  private

    def do_request_without_body request_type, url, additional_headers, authorization_token
      uri = URI.parse(url)
      request_method = request_type_factory(request_type, uri)
      send_request uri, request_method, additional_headers, authorization_token
    end

    def do_request_with_body request_type, url, request_body, additional_headers, authorization_token
      uri = URI.parse(url)
      request_method = request_type_factory(request_type, uri)
      request_method["Content-Type"] = JSON_MIME
      if request_body.is_a?(String)
        request_method.body = request_body
      else
        request_method.body = request_body.to_json
      end
      send_request uri, request_method, additional_headers, authorization_token
    end
    
    def json_response? response
      response['content-type'].to_s.include? JSON_MIME
    end

    def request_type_factory request_type, uri
      case request_type
      when :get
        return Net::HTTP::Get.new(uri)
      when :post
        return Net::HTTP::Post.new(uri)
      when :put
        return Net::HTTP::Put.new(uri)
      when :delete
        return Net::HTTP::Delete.new(uri)
      when :patch
        return Net::HTTP::Patch.new(uri)
      else
        raise "Invalid request type #{request_type} requested."
      end

    end

end; end