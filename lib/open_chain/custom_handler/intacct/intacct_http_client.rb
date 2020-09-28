require 'rexml/document'
require 'open_chain/http_client'

module OpenChain; module CustomHandler; module Intacct; class IntacctHttpClient < OpenChain::HttpClient

  protected

    def http_request uri, request, headers: {}, connection_options: {}
      process_response_body(super)
    end

    def before_request_send _uri, _request, headers: {}, connection_options: {}  # rubocop:disable Lint/UnusedMethodArgument
      headers["Content-Type"] = "x-intacct-xml-request"
      nil
    end

    def process_response_body body
      # The response from Intacct should always be an XML document.
      REXML::Document.new(body)
    rescue REXML::ParseException => e
      e.log_me ["Invalid Intacct API Response:\n" + body]
      raise e
    end

end; end; end; end