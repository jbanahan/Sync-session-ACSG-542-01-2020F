require 'open_chain/api/v1/api_json_controller_adapter'

module OpenChain; module Api; module V1; class VariantApiJsonGenerator
  include OpenChain::Api::V1::ApiJsonControllerAdapter

  def initialize jsonizer: nil
    super(core_module: CoreModule::VARIANT, jsonizer: jsonizer)
  end

  def obj_to_json_hash obj
    variant_fields = limit_fields(
      [:var_identifier] +
      custom_field_keys(CoreModule::VARIANT)
    )

    plant_variant_assignment_fields = limit_fields(
      [:pva_plant_name, :pva_company_name, :pva_company_id] +
      custom_field_keys(CoreModule::PLANT_VARIANT_ASSIGNMENT)
    )

    field_list = variant_fields + plant_variant_assignment_fields

    h = to_entity_hash(obj, field_list)
    return h
  end
end; end; end; end;