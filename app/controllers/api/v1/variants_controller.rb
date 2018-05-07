require 'open_chain/api/v1/variant_api_json_generator'

module Api; module V1; class VariantsController < Api::V1::ApiCoreModuleControllerBase

  def core_module
    CoreModule::VARIANT
  end

  def for_vendor_product
    u = current_user

    vendor_id = params[:vendor_id]
    product_id = params[:product_id]

    c = Company.find vendor_id
    raise StatusableError.new("Vendor not found for id #{vendor_id}", 404) unless c.can_view?(u)

    p = Product.find product_id
    raise StatusableError.new("Product not found for id #{product_id}", 404) unless p.can_view?(u)


    results = c.active_variants_as_vendor.where(product_id:p.id).find_all {|v| v.can_view?(u)}.collect {|v| obj_to_json_hash v}
    render json: {variants:results}
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

  def json_generator
    OpenChain::Api::V1::VariantApiJsonGenerator.new
  end
end; end; end
