class QuickSearchController < ApplicationController
  FIELDS_BY_MODULE = {
    CoreModule::ORDER=>[:ord_ord_num, :ord_cust_ord_no],
    CoreModule::PRODUCT=>[:prod_uid,:prod_name],
    CoreModule::ENTRY=>[:ent_brok_ref,:ent_entry_num,:ent_po_numbers,:ent_customer_references,:ent_mbols,:ent_container_nums,:ent_cargo_control_number,:ent_hbols,:ent_commercial_invoice_numbers],
    CoreModule::SECURITY_FILING=>[:sf_transaction_number,:sf_entry_numbers,:sf_entry_reference_numbers,:sf_po_numbers,:sf_master_bill_of_lading,:sf_container_numbers,:sf_house_bills_of_lading, :sf_host_system_file_number],
    CoreModule::BROKER_INVOICE=>[:bi_brok_ref],
    CoreModule::SHIPMENT=>[:shp_ref,:shp_master_bill_of_lading,:shp_house_bill_of_lading,:shp_booking_number],
    CoreModule::SALE=>[:sale_order_number],
    CoreModule::DELIVERY=>[:del_ref],
    CoreModule::OFFICIAL_TARIFF=>[:ot_hts_code,:ot_full_desc],
    CoreModule::COMPANY=>[:cmp_name]
  }

  def show
    if params[:v].blank?
      error_redirect "You must enter a search value." 
      return
    end
    @value = params[:v].strip
    @available_modules = []
    FIELDS_BY_MODULE.keys.each do |m|
      @available_modules << m if m.view?(current_user)
    end
  end

  def by_module
    cm = CoreModule.find_by_class_name(params[:module_type])
    raise ActionController::RoutingError.new('Not Found') unless cm && cm.view?(current_user)
    return error_redirect("Parameter v is required.") if params[:v].blank?
    r = {module_type: cm.class_name, fields:{}, vals:[], search_term:ActiveSupport::Inflector.transliterate(params[:v].to_s.strip)}
    with_fields_to_use(cm,current_user) do |uids|
      or_clause_array = []
      
      uids.each do |uid|
        mf = ModelField.find_by_uid(uid)
        r[:fields][mf.uid] = mf.label
        
        sc = SearchCriterion.new(model_field_uid:mf.uid.to_s, operator:'co', value: r[:search_term])
        value = sc.where_value
        or_clause_array << ActiveRecord::Base.send(:sanitize_sql_array, ["(#{sc.where_clause(value)})", value])
      end

      results = cm.quicksearch_lambda.call(current_user, cm.klass)
      results = results.where(or_clause_array.join(' OR ')).limit(10)

      sql = results.to_sql
      results.each do |obj|
        obj_hash = {
          id:obj.id,
          view_url: instance_exec(obj, &cm.view_path_proc)
        }
        uids.each {|uid| obj_hash[uid] = ModelField.find_by_uid(uid).process_export(obj,current_user)}
        r[:vals] << obj_hash
      end
    end

    render json: {qs_result:r}
  end

  def with_fields_to_use core_module, user
    @@custom_def_reset ||= nil
    @@qs_field_cache ||= {}
    if @@custom_def_reset.nil? || CustomDefinition.last.pluck(:updated_at) > @@custom_def_reset
      @@qs_field_cache = {}
      FIELDS_BY_MODULE.each do |k,v|
        @@qs_field_cache[k] = v
      end
      cds = CustomDefinition.find_all_by_quick_searchable true
      cds.each do |cd|
        field_array = @@qs_field_cache[cd.core_module]
        field_array << cd.model_field.uid if field_array
      end
    end

    if @@qs_field_cache[core_module]
      yield @@qs_field_cache[core_module]
    else
      yield []
    end
    return nil
  end
  private :with_fields_to_use
end
