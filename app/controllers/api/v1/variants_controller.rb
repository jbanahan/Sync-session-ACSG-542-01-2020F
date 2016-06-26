module Api; module V1; class VariantsController < Api::V1::ApiCoreModuleControllerBase

  def core_module
    CoreModule::VARIANT
  end

  def render_obj obj
    if obj
      obj.freeze_all_custom_values_including_children
    end
    super obj
  end

  def model_fields
    render_model_field_list CoreModule::VARIANT
  end

  def base_relation
    # Don't pre-load custom values, they'll be loaded later by the custom value freeze (which is actually more efficient)
    Variant.includes([{plant_variant_assignments: {plant: :company}}])
  end

  def obj_to_json_hash obj
    variant_fields = limit_fields(
      [:var_identifier] +
      custom_field_keys(CoreModule::VARIANT)
    )

    plant_variant_assignment_fields = limit_fields(
      [:pva_plant_name,:pva_company_name,:pva_company_id] +
      custom_field_keys(CoreModule::PLANT_VARIANT_ASSIGNMENT)
    )

    field_list = variant_fields + plant_variant_assignment_fields

    h = to_entity_hash(obj, field_list)
    return h
  end
end; end; end
