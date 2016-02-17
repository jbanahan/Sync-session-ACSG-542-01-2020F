module Api; module V1; class ProductVendorAssignmentsController < Api::V1::ApiCoreModuleControllerBase
  def core_module
    CoreModule::PRODUCT_VENDOR_ASSIGNMENT
  end
  def index
    render_search core_module
  end

  def show
    render_show core_module
  end

  def bulk_update
    ActiveRecord::Base.transaction do
      assignment_array = params[:product_vendor_assignments]
      if assignment_array.blank? || !assignment_array.is_a?(Array)
        raise StatusableError.new("Product vendor assignments should be in JSON array under element 'product_vendor_assignments'.",400)
      end
      assignment_array.each do |pva_hash|
        id = pva_hash['id']
        raise StatusableError.new("Each record must provide an id element.",400) if id.blank?
        pva = generic_save_object pva_hash
        if pva.errors.full_messages.blank?
          pva.create_async_snapshot if pva.respond_to?('create_async_snapshot')
        else
          raise StatusableError.new(pva.errors.full_messages, 400)
        end
      end
    end
    render json: {'ok'=>'ok'}
  end

  def obj_to_json_hash o
    headers_to_render = limit_fields([
      :prodven_puid,
      :prodven_pname,
      :prodven_ven_name,
      :prodven_ven_syscode,
      :prodven_prod_ord_count
    ] + custom_field_keys(core_module))
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


end; end; end
