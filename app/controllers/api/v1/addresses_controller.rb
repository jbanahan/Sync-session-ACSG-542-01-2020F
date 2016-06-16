module Api; module V1; class AddressesController < Api::V1::ApiCoreModuleControllerBase

  def core_module
    CoreModule::ADDRESS
  end

  def autocomplete
    json = []
    if !params[:n].blank?
      result = Address.where('addresses.name like ?',"%#{params[:n]}%").where(in_address_book:true).joins(:company).where(Company.secure_search(current_user))
      result = result.order(:name)
      result = result.limit(10)
      json = result.map {|address| {name:address.name, full_address:address.full_address, id:address.id} }
    end

    render json: json
  end

  def create
    address = Address.create! params[:address]
    render json: address
  end

  def obj_to_json_hash a
    headers_to_render = limit_fields([
      :add_syscode,
      :add_name,
      :add_line_1,
      :add_line_2,
      :add_line_3,
      :add_city,
      :add_state,
      :add_postal_code,
      :add_created_at,
      :add_updated_at,
      :add_shipping,
      :add_phone_number,
      :add_fax_number,
      :add_full_address
    ] + custom_field_keys(CoreModule::ADDRESS))
    h = to_entity_hash(a, headers_to_render)
    h['map_url'] = a.google_maps_url
    h
  end

end; end; end
