require 'open_chain/http_client'

module OpenChain; class JsonHttpClient < HttpClient

  JSON_MIME ||= "application/json".freeze

  def get url, additional_headers = {}, authorization_token = nil
    uri = URI.parse(url)
    get = Net::HTTP::Get.new(uri)
    send_request uri, get, additional_headers, authorization_token
  end

  def post url, request_body, additional_headers = {}, authorization_token = nil
    uri = URI.parse(url)
    post = Net::HTTP::Post.new(uri)
    post["Content-Type"] = JSON_MIME
    post.body = request_body.to_json
    send_request uri, post, additional_headers, authorization_token
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
    
    def json_response? response
      response['content-type'].to_s.include? JSON_MIME
    end

end; end