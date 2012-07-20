class QuickSearchController < ApplicationController

  def show
    error_redirect "You must enter a search value." if params[:v].blank?
    @module_field_map = {
      CoreModule::ORDER=>[:ord_ord_num],
      CoreModule::PRODUCT=>[:prod_uid,:prod_name],
      CoreModule::ENTRY=>[:ent_brok_ref,:ent_entry_num,:ent_po_numbers,:ent_customer_references,:ent_mbols,:ent_container_nums],
      CoreModule::BROKER_INVOICE=>[:bi_brok_ref],
      CoreModule::SHIPMENT=>[:shp_ref],
      CoreModule::SALE=>[:sale_order_number],
      CoreModule::DELIVERY=>[:del_ref]
    }
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
