module OpenChain

class HttpErrorWithResponse < StandardError
  attr_accessor :http_status
  attr_accessor :http_response_body
end

class HttpClient

  def http_request uri, request, additional_headers = {}, connection_options = {}
    retry_count = 0
    response = nil
    status = nil
    response_body = nil
    begin
      connect_options = {:read_timeout => 120, :open_timeout => 10}
      if uri.scheme == "https"
        connect_options[:use_ssl] = true
        connect_options[:verify_mode] = OpenSSL::SSL::VERIFY_NONE
      end

      connect_options = connect_options.merge connection_options

      if additional_headers
        additional_headers.each_pair do |name, value|
          request[name] = value
        end
      end
      request["Host"] = uri.host

      response = Net::HTTP.start(uri.host, uri.port, connect_options) do |http|
        if block_given?
          yield http, request
        end
        
        http.request request
      end
      
      status = response.code

      # This method will modify the character encoding of the response so that it matches the headers
      update_response_body_encoding response
      response_body = process_response response

      raise "Server responded with an error: #{status}" unless status == "200"
    rescue => e
      # There's no real point in retrying any error that actually returned a status.  We'll let any higher level
      # classes determine if they want to retry something like 5XX series errors
      if status
        err = HttpErrorWithResponse.new e.message
        err.http_status = status
        err.http_response_body = response_body unless response_body.nil?
        raise err
      else
        # If we didn't get a status, it means the request never actually went through, so go ahead and retry the request.
        retry_count += 1
        if retry_count < 3
          response = nil
          response_body = nil
          status = nil
          sleep 1
          retry
        end
      end

      # At this point, just re-raise the error
      raise e
    end

    response_body
  end

  def process_response response
    # Allows easy transformation/translation of the response body (.ie to json or whatnot)
    response.body
  end

  private 
    def update_response_body_encoding response
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

    end

end; end;