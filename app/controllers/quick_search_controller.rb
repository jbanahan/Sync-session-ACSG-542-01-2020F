class QuickSearchController < ApplicationController

  def show
    error_redirect "You must enter a search value." if params[:v].blank?
    all_modules = [CoreModule::ORDER,CoreModule::PRODUCT,CoreModule::ENTRY,CoreModule::INVOICE,CoreModule::SHIPMENT,CoreModule::SALE,CoreModule::DELIVERY]
    @modules = all_modules.collect {|m| m.view? current_user}
    @value = params[:v]
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
      search_results = k.search_secure(current_user,search_results).limit(10)
      default_fields = cm.default_search_columns
      default_fields = default_fields[0,3] if default_fields.size > 3
      model_fields = default_fields.collect {|mfuid| ModelField.find_by_uid mfuid}
      r["headings"] = model_fields.collect {|m| m.label}
      r["rows"] = []
      search_results.each do |o| 
        row = Hash.new
        row["values"] = model_fields.collect {|m| m.process_export(o)}
        row["link"] = url_for o
        r["rows"] << row
      end
    end

    render :json => r.to_json
  end

end
