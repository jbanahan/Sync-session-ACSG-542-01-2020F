class QuickSearchController < ApplicationController

  def show
    if params[:v].blank?
      error_redirect "You must enter a search value." 
      return
    end
    @module_field_map = {
      CoreModule::ORDER=>[:ord_ord_num, :ord_cust_ord_no],
      CoreModule::PRODUCT=>[:prod_uid,:prod_name],
      CoreModule::ENTRY=>[:ent_brok_ref,:ent_entry_num,:ent_po_numbers,:ent_customer_references,:ent_mbols,:ent_container_nums,:ent_cargo_control_number,:ent_hbols,:ent_commercial_invoice_numbers],
      CoreModule::SECURITY_FILING=>[:sf_transaction_number,:sf_entry_numbers,:sf_entry_reference_numbers,:sf_po_numbers,:sf_master_bill_of_lading,:sf_container_numbers,:sf_house_bills_of_lading, :sf_host_system_file_number],
      CoreModule::BROKER_INVOICE=>[:bi_brok_ref],
      CoreModule::SHIPMENT=>[:shp_ref,:shp_master_bill_of_lading,:shp_house_bill_of_lading,:shp_booking_number],
      CoreModule::SALE=>[:sale_order_number],
      CoreModule::DELIVERY=>[:del_ref],
      CoreModule::OFFICIAL_TARIFF=>[:ot_hts_code,:ot_full_desc]
    }
    # Find and add all custom fields that are enabled as quick searchable
    cds = CustomDefinition.find_all_by_quick_searchable true
    cds.each do |cd|
      mf = cd.model_field
      if mf 
          field_map = @module_field_map[mf.core_module]
          if field_map
            field_map << mf.uid
          end
      end
    end
    @module_field_map.delete_if {|k,v| !k.view?(current_user)}
    @value = params[:v].strip
    render :layout=>'one_col'
  end

  # return a json result for the given search term and core module
  def module_result
    r = Hash.new
    mf = ModelField.find_by_uid params[:mfid]
    cm = mf.core_module unless mf.nil? 
    if mf.nil?
      r["error"] = "You must specify a search field."
    elsif !cm.view?(current_user)
      r["error"] = "You do not have permission to search for module \"#{cm.label}\"."
    elsif params[:v].blank?
      r["errors"] = "You must enter a search value."
    else
      k = cm.klass 
      search_results = SearchCriterion.new(:model_field_uid=>params[:mfid],:operator=>"co",:value=>params[:v].strip).apply k
      search_results = k.search_secure(current_user,search_results).limit(11).order("#{cm.table_name}.id DESC").select("DISTINCT(#{cm.table_name}.id)")
      search_results = cm.klass.where("ID IN (?)",search_results.collect {|sr| sr.id})
      default_fields = cm.default_search_columns
      default_fields = default_fields[0,3] if default_fields.size > 3
      model_fields = default_fields.collect {|mfuid| ModelField.find_by_uid mfuid}
      r["headings"] = model_fields.collect {|m| m.label}
      r["rows"] = []
      search_results.each do |o| 
        row = Hash.new
        row["values"] = model_fields.collect {|m| 
          v = m.process_export(o,current_user)
          if !v.blank?
            case m.data_type
            when :date
              v = v.strftime("%Y-%m-%d")
            when :datetime
              v = v.strftime("%Y-%m-%d %H:%M")
            end
          else
            v = ""
          end
          v
        }
        row["link"] = url_for o
        row["id"] = o.id
        r["rows"] << row
      end
    end

    render :json => r.to_json
  end

end
