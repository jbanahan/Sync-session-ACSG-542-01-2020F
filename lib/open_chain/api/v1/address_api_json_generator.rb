require 'open_chain/api/v1/api_json_controller_adapter'

module OpenChain; module Api; module V1; class AddressApiJsonGenerator
  include OpenChain::Api::V1::ApiJsonControllerAdapter

  def initialize jsonizer: nil
    super(core_module: CoreModule::ADDRESS, jsonizer: jsonizer)
  end

  def obj_to_json_hash a
    headers_to_render = limit_fields(field_list(CoreModule::ADDRESS))
    h = to_entity_hash(a, headers_to_render)
    h['map_url'] = a.google_maps_url
    h
  end
end; end; end; end;