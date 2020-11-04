require 'open_chain/integration_client_parser'

module OpenChain; module IntegrationParserBroker
  extend ActiveSupport::Concern
  include OpenChain::IntegrationClientParser

  module ClassMethods
    def parse data, opts = {}
      parser = create_parser(opts[:bucket], opts[:key], data, opts)
      # We want to update the inbound file that the integration client parser provides and
      # rekey it to the actual parser utilized.
      inbound_file.parser_name = parser_class_name(parser)

      parser.parse(data, opts)
    end

    def create_parser _bucket, _key, _data, _opts
      raise "All including classes must implement a create_parser class method that will return the brokered parser to utilize to process the given data."
    end
  end

end; end