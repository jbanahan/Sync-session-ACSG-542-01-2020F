require 'open_chain/api/api_entity_jsonizer'

module OpenChain; module Api; module ApiJsonGeneratorContextProvider

  attr_reader :params, 

  def initialize params:, jsonizer: OpenChain::Api::ApiEntityJsonizer.new
    @params = params
  end

  def limit_fields

  end

end; end; end;