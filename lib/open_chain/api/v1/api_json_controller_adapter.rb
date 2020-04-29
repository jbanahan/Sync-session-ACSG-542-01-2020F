require 'open_chain/api/api_entity_jsonizer'
require 'open_chain/api/v1/api_json_support'

# This class is a first step at moving the API json generation outside of the actual controller
# classes.  The actual json generation in api_json_support relies  HEAVILY on controller methods to determine
# which fields/relations to generate, etc... My hope is to eventually abstract/extract all of that
# out so that generating a json entity has no real dependence on a controller environment. That's a
# much large project than I have time allotted for at the moment, so this is a bit of a stopgap.
#
# This class is intended to be included on all module specific implementations of ApiJsonGenerators.
# If this class is included, the base class must implement an initializer that sets params, current user
# and the core module.
module OpenChain; module Api; module V1; module ApiJsonControllerAdapter
  include OpenChain::Api::V1::ApiJsonSupport

  attr_reader :core_module
  attr_accessor :json_context

  def initialize core_module:, jsonizer: nil
    @core_module = core_module
    if jsonizer
      super(jsonizer: jsonizer)
    else
      super()
    end
  end

  def params
    @json_context.params
  end

  def current_user
    @json_context.current_user
  end

end; end; end; end;