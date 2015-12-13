# A bunch of stuff that was extracted from application controller for readability
module OpenChain; module ApplicationControllerLegacy
  # show user message and redirect for http(s)://*.chain.io/*
  def chainio_redirect
    if request.original_url.match(/https?:\/\/[a-zA-Z]*\.chain\.io\//) 
      @original_url = request.url
      @new_url = @original_url.sub(/chain\.io/,'vfitrack.net')
      @new_domain = @new_url.match(/[a-zA-Z]*\.vfitrack\.net/).to_s
      render 'shared/no_chain'
    end
  end

  def redirect_by_core_module core_module, force_search=false
    redirect_path = "root_path"
    case core_module
    when CoreModule::ORDER_LINE
      redirect_path = "orders_path"
    when CoreModule::ORDER
      redirect_path = "orders_path"
    when CoreModule::SHIPMENT_LINE
      redirect_path = "shipments_path"
    when CoreModule::SHIPMENT
      redirect_path = "shipments_path"
    when CoreModule::SALE_LINE
      redirect_path = "sales_orders_path"
    when CoreModule::SALE 
      redirect_path = "sales_orders_path"
    when CoreModule::DELIVERY_LINE
      redirect_path = "deliveries_path"
    when CoreModule::DELIVERY
      redirect_path = "deliveries_path"
    when CoreModule::TARIFF
      redirect_path = "products_path"
    when CoreModule::CLASSIFICATION
      redirect_path = "products_path"
    when CoreModule::PRODUCT
      redirect_path = "products_path"
    when CoreModule::OFFICIAL_TARIFF
      redirect_path = "official_tariffs_path"
    when CoreModule::DRAWBACK_CLAIM
      redirect_path = "drawback_claims_path"
    end

    search_params = {}
    if force_search
      search_params[:force_search] = true
    end

    redirect_to send(redirect_path.to_sym, search_params)
  end

  class SearchResult
    attr_accessor :records
    attr_accessor :columns
    attr_accessor :name
  end
  class ResultRecord
    attr_accessor :data
    attr_accessor :url
  end

  def advanced_search(core_module,force_search=false, clear_selected_items = false)
    search_run = nil
    if force_search
      search_run = SearchRun.
        includes(:search_setup).
        where("search_setups.module_type = ?",core_module.class_name).
        where(:user_id=>current_user.id).
        where("search_setups.user_id = ?",current_user.id).
        order("ifnull(search_runs.last_accessed,1900-01-01) DESC").
        first
    else
      search_run = SearchRun.find_last_run current_user, core_module
    end
    if search_run.nil?
      setup = current_user.search_setups.order("updated_at DESC").where(:module_type=>core_module.class_name).limit(1).first
      setup = core_module.make_default_search(current_user) unless setup
      search_run = setup.search_runs.create!
    end
    page_number = (search_run.page ? search_run.page : nil)
    page_str = page_number ? "/#{page_number}" : ''
    parent = search_run.parent
    case parent.class.to_s
    when 'SearchSetup'
      return "/advanced_search#/#{parent.id}#{page_str}#{clear_selected_items ? "?clearSelection=true" : ""}"
    when 'ImportedFile'
      return "/imported_files/show_angular#/#{parent.id}#{page_str}"
    when 'CustomFile'
      return "/custom_files/#{parent.id}"
    else
      raise "advanced_search has no routing for class: #{parent.class}"
    end
  end

  #save and validate a base_object representing a CoreModule like a product instance or a sales_order instance
  #this method will automatically save custom fields and will rollback if the validation fails
  #if you set the raise_exception parameter to true then the method will throw the OpenChain::FieldLogicValidator exception (useful for wrapping in a larger transaction)
  def validate_and_save_module base_object, parameters, succeed_lambda, fail_lambda, opts={}
    OpenChain::CoreModuleProcessor.validate_and_save_module params, base_object, parameters, current_user, succeed_lambda, fail_lambda, opts
  end

  #loads the custom values into the parent object without saving
  def set_custom_fields customizable_parent, customizable_parent_params = nil, &block
    cpp = customizable_parent_params.nil? ? params[(customizable_parent.class.to_s.downcase+"_cf").intern] : customizable_parent_params
    OpenChain::CoreModuleProcessor.set_custom_fields customizable_parent, cpp, current_user, &block
  end

  def update_custom_fields customizable_parent, customizable_parent_params=nil
    cpp = customizable_parent_params.nil? ? params[(customizable_parent.class.to_s.downcase+"_cf").intern] : customizable_parent_params
    OpenChain::CoreModuleProcessor.update_custom_fields customizable_parent, cpp, current_user
  end
  
  def update_status(statusable)
    OpenChain::CoreModuleProcessor.update_status statusable
  end
    
  #subclassed controller must implement secure method that returns searchable object 
  #and if custom fields are used then a root_class method that returns the class of the core object being worked with (OrdersController would return Order)
  def build_search(base_field_list,default_search,default_sort,default_sort_order='a')
    field_list = base_field_list
    begin
      field_list = self.root_class.new.respond_to?("custom_definitions") ? base_field_list.merge(custom_field_parameters(root_class.new)) : base_field_list
    rescue NoMethodError 
      #this is ok, you just won't get your custom fields
    end
    @s_params = field_list
    @selected_search = params[:f]
    @s_search = field_list[params[:f]]
    if @s_search.nil?
      @s_search = field_list[default_search]
      @selected_search = default_search 
    end
    @s_con = params[:c].nil? ? 'contains' : params[:c]
    sval = params[:s]
    sval = true if ['is_null','is_not_null','is_true','is_false'].include? @s_con
    @search = add_search_relation secure, @s_search, @s_con, sval
    @s_sort = field_list[params[:sf]]
    @s_sort = field_list[default_sort] if @s_sort.nil?
    @s_order = ['a','d'].include?(params[:so]) ? params[:so] : default_sort_order
    @search = add_sort_relation @search, @s_sort, @s_order
    return @search
  end

  def add_search_relation relation, field_definition, operator, value
    field = field_definition[:field]

    if field_definition[:datatype] == :boolean
      if value.blank? || ['y', 'true', '1', 'yes'].include?(value.to_s.strip.downcase)
        relation.where("#{field} = ?", true)
      else
        relation.where("#{field} = ? OR #{field} IS NULL", false)
      end
    else
      # This is just some handling for cases where user doesn't actually key anything into the search field
      return relation if value.blank? && ['contains', 'eq', 'sw', 'ew'].include?(operator)

      # The cast in here is solely to handle non-string fields (like dates or numbers)
      case operator
      when "contains"
        relation.where("CAST(#{field} as char) LIKE ?", "%#{value}%")
      when "eq"
        relation.where("#{field} = ?", value)
      when "sw"
        relation.where("CAST(#{field} as char) LIKE ?", "#{value}%")
      when "ew"
        relation.where("CAST(#{field} as char) LIKE ?", "%#{value}")
      when "is_null"
        relation.where("#{field} IS NULL OR LENGTH(TRIM(CAST(#{field} as char))) = 0")
      when "is_not_null"
        relation.where("LENGTH(TRIM(CAST(#{field} as char))) > 0")
      else
        relation
      end
    end
  end

  def add_sort_relation relation, field, order
    relation.order("#{field[:field]} #{order=="d" ? "DESC" : "ASC"}")
  end
  
  def custom_field_parameters(customizable)
    r = {}
    customizable.custom_definitions.each do |d|
      r["cf_#{d.id}#{d.date? ? "_date" : "_"}"] = {:field => "#{d.id}", :label=> d.label, :custom => true}
    end
    r
  end

  def get_search_to_run
    return SearchSetup.for_module(@core_module).for_user(current_user).where(:id=>params[:sid]).first unless params[:sid].nil?
    s = SearchSetup.last_accessed(current_user, @core_module).first
    s = @core_module.make_default_search current_user if s.nil?
    s
  end
  
  def search_run
    return nil unless self.respond_to?('root_class') || @core_module
    @core_module = CoreModule.find_by_class_name self.root_class.to_s unless @core_module
    sr = SearchRun.find_last_run current_user, @core_module
    if sr.nil?
      ss = get_search_to_run
      sr = ss.search_run
      sr = ss.create_search_run if sr.nil?
    end
    sr
  end

  


end; end