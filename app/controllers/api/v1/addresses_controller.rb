require 'open_chain/api/v1/address_api_json_generator'

module Api; module V1; class AddressesController < Api::V1::ApiCoreModuleControllerBase

  def core_module
    CoreModule::ADDRESS
  end

  def destroy
    a = Address.find_by_id(params[:id])
    raise StatusableError.new("Address with id #{params[:id]} not found.", 404) unless a
    raise StatusableError.new("You do not have permission to edit this address", :forbidden) unless a.can_edit?(current_user)
    if !a.destroy
      raise StatusableError.new(a.errors.full_messages)
    end
    render json: {'ok'=>'ok'}
  end

  def autocomplete
    json = []
    if !params[:n].blank?
      result = Address.where('addresses.name like ?', "%#{params[:n]}%").where(in_address_book:true).joins(:company).where(Company.secure_search(current_user))
      result = result.order(:name)
      result = result.limit(10)
      json = result.map {|address| {name:address.name, full_address:address.full_address_array(skip_name: true).join("\n"), id:address.id} }
    end

    render json: json
  end

  def save_object h
    a = h['id'].blank? ? new_address(h) : Address.find_by_id(h['id'])
    raise StatusableError.new("Object with id #{h['id']} not found.", 404) if a.nil?
    prevent_company_change(a, h) if a.persisted?
    import_fields h, a, CoreModule::ADDRESS
    prevent_address_hash_change(a) if a.persisted?
    # The reason for the different address permissions on create/update is to allow any user to create an address via the chain-common address
    # panel, as long as they can "view" the address (essentially they are saving it to their company or a linked compnay).
    # If they're editing the address, then they have to have can_edit permission
    if a.persisted?
      raise StatusableError.new("You do not have permission to save this addresss.", :forbidden) unless a.can_edit?(current_user)
    else
      raise StatusableError.new("You do not have permission to create this addresss.", :forbidden) unless a.can_view?(current_user) || a.can_edit?(current_user)
    end
    a.save if a.errors.full_messages.blank?
    a
  end

  def new_address hash
    comp_id = hash['add_comp_db_id']
    raise StatusableError.new("You must specify add_comp_db_id to create a new address.", 401) if comp_id.blank?
    if comp_id == "current_user"
      hash["add_comp_db_id"] = current_user.company_id
      c = current_user.company
    else
      c = Company.search_secure(current_user, Company).where(id:comp_id).first
      raise StatusableError.new("Company #{comp_id} not found.", 404) unless c
    end

    c.addresses.build
  end

  def prevent_company_change a, hash
    comp_id = hash['add_comp_db_id']
    return unless comp_id
    raise StatusableError.new("You cannot change the company for an address.", 401) unless comp_id.to_s == a.company.id.to_s
  end

  def prevent_address_hash_change a
    if !a.address_hash.blank? && a.address_hash != Address.make_hash_key(a)
      raise StatusableError.new("You cannot change the address, only its setup flags.", 401)
    end
  end

  def json_generator
    OpenChain::Api::V1::AddressApiJsonGenerator.new
  end

  # overrides ApiCoreModuleControllerBase
  def max_per_page
    1000
  end

end; end; end
