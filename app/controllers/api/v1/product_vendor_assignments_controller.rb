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

  # create multiple product vendor assignments
  # JSON request must contain two arrays indicating the product & vendor:
  #
  # product_ids or prod_uids are both acceptable for the product
  # vendor_ids or cmp_sys_codes are both acceptable for the vendor
  #
  # you may also provide an optional product_vendor_assignment object which will be used to update
  # each record with its content after the record is created
  #
  # Sample: {
  #   'product_ids':[1,2,3],
  #   'cmp_sys_codes':['VEND1','VEND2'],
  #   'product_vendor_assignment':{'*cf_1':'OtherFieldUpdate'}
  # }
  #
  # The sample above would create 6 records by assoicated each of the 3 products with each of the 2 vendors
  # All 6 products would have Custom Field 1 updated with the value 'OtherFieldUpdate'
  def bulk_create
    ActiveRecord::Base.transaction do
      product_ids = params[:product_ids]
      prod_uids = params[:prod_uids]
      product_count = [product_ids,prod_uids].inject(0) {|int,mem| int + (mem.blank? ? 0 : mem.size)}
      vendor_ids = params[:vendor_ids]
      vendor_system_codes = params[:cmp_sys_codes]
      vendor_count = [vendor_ids,vendor_system_codes].inject(0) {|int,mem| int + (mem.blank? ? 0 : mem.size)}
      raise StatusableError.new("Request failed, you may only request up to 100 assignments at a time.") if (product_count*vendor_count) > 100


      u = current_user
      products_to_assign = []
      vendors_to_assign = []

      # find products by ID
      missing_product_ids = []
      if !product_ids.blank?
        product_ids = product_ids.collect {|id| id.to_s}
        products_by_id = Product.where("products.id IN (?)",product_ids)
        products_to_assign += products_by_id

        # figure out what wasn't found so we can tell the user
        product_ids_found = []
        products_by_id.each do |p|
          raise StatusableError.new("You do not have permission to edit all products found.",400) unless p.can_edit?(u)
          product_ids_found << p.id.to_s
        end
        missing_product_ids = product_ids - product_ids_found
      end

      # find products by unique identifier
      missing_prod_uids = []
      if !prod_uids.blank?
        products_by_uid = Product.where("products.unique_identifier IN (?)",prod_uids)
        products_to_assign += products_by_uid

        # figure out what wasn't foudn so we can tell the user
        prod_uids_found = []
        products_by_uid.each do |p|
          raise StatusableError.new("You do not have permission to edit all products found.",400) unless p.can_edit?(u)
          prod_uids_found << p.unique_identifier
        end
        missing_prod_uids = prod_uids - prod_uids_found
      end

      # find vendors by ID
      missing_vendor_ids = []
      if !vendor_ids.blank?
        vendor_ids = vendor_ids.collect {|id| id.to_s}
        vendors_by_id = Company.where("companies.id IN (?)",vendor_ids)
        vendors_to_assign += vendors_by_id

        # figure out what wasn't found so we can tell the user
        vendor_ids_found = []
        vendors_by_id.each do |v|
          raise StatusableError.new("You do not have permission to edit all vendors found.",400) unless v.can_edit?(u)
          vendor_ids_found << v.id.to_s
        end
        missing_vendor_ids = vendor_ids - vendor_ids_found
      end

      # find vendors by system_code
      missing_vendor_system_codes = []
      if !vendor_system_codes.blank?
        vendors_by_system_code = Company.where("companies.system_code IN (?)",vendor_system_codes)
        vendors_to_assign += vendors_by_system_code

        # figure out what wasn't found so we can tell the user
        vendor_system_codes_found = []
        vendors_by_system_code.each do |v|
          raise StatusableError.new("You do not have permission to edit all vendors found.",400) unless v.can_edit?(u)
          vendor_system_codes_found << v.system_code.to_s
        end
        missing_vendor_system_codes = vendor_system_codes - vendor_system_codes_found
      end

      # do assignments
      products_to_assign.each do |p|
        vendors_to_assign.each do |v|
          pva = ProductVendorAssignment.where(vendor_id:v.id,product_id:p.id).first_or_create!
          if !params[:product_vendor_assignment].blank?
            obj_hash = params[:product_vendor_assignment].clone
            obj_hash['id'] = pva.id
            generic_save_existing_object(pva,obj_hash)
          end
          pva.create_async_snapshot if pva.respond_to?('create_async_snapshot')
        end
      end
      assignment_count = products_to_assign.size * vendors_to_assign.size

      # report messages back to user
      messages = []
      messages << "Products with IDs \"#{missing_product_ids.join(", ")}\" not found." unless missing_product_ids.empty?
      messages << "Products with #{ModelField.find_by_uid(:prod_uid).label} \"#{missing_prod_uids.join(", ")}\" not found." unless missing_prod_uids.empty?
      messages << "Vendors with IDs \"#{missing_vendor_ids.join(", ")}\" not found." unless missing_vendor_ids.empty?
      messages << "Products with #{ModelField.find_by_uid(:cmp_sys_code).label} \"#{missing_vendor_system_codes.join(", ")}\" not found." unless missing_vendor_system_codes.empty?
      messages << "#{assignment_count} product / vendor assignments created." if assignment_count > 0

      render json: {messages:messages}
    end
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


end; end; end
