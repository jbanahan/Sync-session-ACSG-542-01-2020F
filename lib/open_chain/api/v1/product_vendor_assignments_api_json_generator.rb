require 'open_chain/api/v1/api_json_controller_adapter'

module OpenChain; module Api; module V1; class ProductVendorAssignmentApiJsonGenerator
  include OpenChain::Api::V1::ApiJsonControllerAdapter

  def initialize jsonizer: nil
    super(core_module: CoreModule::PRODUCT_VENDOR_ASSIGNMENT, jsonizer: jsonizer)
  end

  def obj_to_json_hash o
    headers_to_render = limit_fields([
      :prodven_puid,
      :prodven_pname,
      :prodven_ven_name,
      :prodven_ven_syscode,
      :prodven_prod_ord_count
    ] + custom_field_keys(core_module))

    # add product level custom field uids
    CoreModule::PRODUCT_VENDOR_ASSIGNMENT.model_fields.keys.each do |uid|
      headers_to_render << uid if uid.to_s.match(/^\*cf.*product_vendor_assignment/)
    end

    h = to_entity_hash(o, headers_to_render)
    h['product_id'] = o.product_id
    h['vendor_id'] = o.vendor_id
    h['permissions'] = render_permissions(o)
    h
  end

  def render_permissions obj
    cu = current_user #current_user is method, so saving as variable to prevent multiple calls
    {
      can_view: obj.can_view?(cu),
      can_edit: obj.can_edit?(cu)
    }
  end
  
end; end; end; end;