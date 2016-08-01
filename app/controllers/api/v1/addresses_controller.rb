module Api; module V1; class AddressesController < Api::V1::ApiCoreModuleControllerBase

  def core_module
    CoreModule::ADDRESS
  end

  def destroy
    a = Address.find_by_id(params[:id])
    raise StatusableError.new("Address with id #{params[:id]} not found.",404) unless a
    raise StatusableError.new("You do not have permission to edit this address",:forbidden) unless a.can_edit?(current_user)
    if !a.destroy
      raise StatusableError.new(a.errors.full_messages)
    end
    render json: {'ok'=>'ok'}
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

  def save_object h
    a = h['id'].blank? ? new_address(h) : Address.find_by_id(h['id'])
    raise StatusableError.new("Object with id #{h['id']} not found.",404) if a.nil?
    prevent_company_change a, h
    import_fields h, a, CoreModule::ADDRESS
    prevent_address_hash_change a
    raise StatusableError.new("You do not have permission to save this addresss.",:forbidden) unless a.can_edit?(current_user)
    a.save if a.errors.full_messages.blank?
    a
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

  def new_address hash
    comp_id = hash['add_comp_db_id']
    raise StatusableError.new("You must specify add_comp_db_id to create a new address.",401) if comp_id.blank?
    c = Company.search_secure(current_user,Company).where(id:comp_id).first
    raise StatusableError.new("Company #{comp_id} not found.",404) unless c
    c.addresses.build
  end

  def prevent_company_change a, hash
    comp_id = hash['add_comp_db_id']
    return unless comp_id
    raise StatusableError.new("You cannot change the company for an address.",401) unless comp_id.to_s == a.company.id.to_s
  end

  def prevent_address_hash_change a
    if !a.address_hash.blank? && a.address_hash != Address.make_hash_key(a)
      raise StatusableError.new("You cannot change the address, only its setup flags.",401)
    end
  end

end; end; end
