class ApplicationController < ActionController::Base
  require 'open_chain/field_logic'
  require 'yaml'
  require 'newrelic_rpm'

  protect_from_forgery
  before_filter :prep_model_fields
  before_filter :new_relic
  before_filter :set_master_setup
  before_filter :require_user
  before_filter :set_user_time_zone
  before_filter :log_request
  before_filter :force_reset
  before_filter :set_legacy_scripts

  helper_method :current_user
  helper_method :master_company
  helper_method :add_flash
  helper_method :has_messages
  helper_method :errors_to_flash
  helper_method :hash_flip
  helper_method :merge_params
  helper_method :sortable_search_heading
  helper_method :master_setup

  after_filter :reset_state_values
 

  def log_request
    #prep for exception notification
    request.env["exception_notifier.exception_data"] = {
      :user => current_user
    } if current_user
    #user level application "debug" logging
    if current_user && current_user.debug_active?
      DebugRecord.create(:user_id => current_user.id, :request_method => request.method,
          :request_path => request.fullpath, :request_params => sanitize_params_for_log(params).to_yaml)
    end
  end

  def help
      Helper.instance
  end

  class Helper
      include Singleton
      include ActionView::Helpers::TextHelper
      include ActionView::Helpers::UrlHelper
      include ActionView::Helpers::SanitizeHelper
  end

  def master_setup
    MasterSetup.get
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
    end
    if force_search
      redirect_to eval(redirect_path<<"(:force_search=>true)")
    else
      redirect_to eval(redirect_path)
    end
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

  def advanced_search(core_module,force_search=false)
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
      return "/advanced_search#/#{parent.id}#{page_str}"
    when 'ImportedFile'
      return "/imported_files/show_angular#/#{parent.id}#{page_str}"
    when 'CustomFile'
      return "/custom_files/#{parent.id}"
    else
      raise "advanced_search has no routing for class: #{parent.class}"
    end
  end

  #controller action to display generic history page
  def history
    p = root_class.find params[:id]
    action_secure(p.can_view?(current_user),p,{:verb => "view",:module_name=>"item",:lock_check=>false}) {
      @base_object = p
      @snapshots = p.entity_snapshots.order("entity_snapshots.id DESC").paginate(:per_page=>5,:page => params[:page])
      render 'shared/history'
    }
  end
  
  #save and validate a base_object representing a CoreModule like a product instance or a sales_order instance
  #this method will automatically save custom fields and will rollback if the validation fails
  #if you set the raise_exception parameter to true then the method will throw the OpenChain::FieldLogicValidator exception (useful for wrapping in a larger transaction)
  def validate_and_save_module base_object, parameters, succeed_lambda, fail_lambda, opts={}
    OpenChain::CoreModuleProcessor.validate_and_save_module params, base_object, parameters, succeed_lambda, fail_lambda, opts
  end

  #loads the custom values into the parent object without saving
  def set_custom_fields customizable_parent, customizable_parent_params = nil, &block
    cpp = customizable_parent_params.nil? ? params[(customizable_parent.class.to_s.downcase+"_cf").intern] : customizable_parent_params
    OpenChain::CoreModuleProcessor.set_custom_fields customizable_parent, cpp, &block
  end

  def update_custom_fields customizable_parent, customizable_parent_params=nil
    cpp = customizable_parent_params.nil? ? params[(customizable_parent.class.to_s.downcase+"_cf").intern] : customizable_parent_params
    OpenChain::CoreModuleProcessor.update_custom_fields customizable_parent, cpp
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
    if @s_search[:custom]
      d = CustomDefinition.find(@s_search[:field])
      @search = secure.joins(:custom_values).where("custom_values.custom_definition_id = ?",d.id).search("custom_values_#{d.data_column}_#{@s_con}" => sval)
    else
      @search = secure.search((@s_search[:field]+'_'+@s_con) => sval)
    end
    @s_sort = field_list[params[:sf]]
    @s_sort = field_list[default_sort] if @s_sort.nil?
    @s_order = default_sort_order
    @s_order = params[:so] if !params[:so].nil? && ['a','d'].include?(params[:so])
    @search.meta_sort = @s_sort[:field]+(@s_order=='d' ? '.desc' : '.asc')
    return @search
  end
  
  def custom_field_parameters(customizable)
    r = {}
    customizable.custom_definitions.each do |d|
      r["cf_#{d.id}#{d.date? ? "_date" : "_"}"] = {:field => "#{d.id}", :label=> d.label, :custom => true}
    end
    r
  end
  
  def error_redirect(message=nil)
    add_flash :errors, message unless message.nil?
    target = request.referrer ? request.referrer : "/"
    redirect_to target
  end
    
  def action_secure(permission_check, obj, options={})
    err_msg = nil
    opts = {
      :lock_check => true, 
      :verb => "edit", 
      :lock_lambda => lambda {|obj| obj.respond_to?(:locked?) && obj.locked?},
      :module_name => "object"}.merge(options)
    err_msg = "You do not have permission to #{opts[:verb]} this #{opts[:module_name]}." unless permission_check
    err_msg = "You cannot #{opts[:verb]} #{"aeiou".include?(opts[:module_name].slice(0,1)) ? "an" : "a"} #{opts[:module_name]} with a locked company." if opts[:lock_check] && opts[:lock_lambda].call(obj) 
    unless err_msg.nil?
      error_redirect err_msg
    else
      yield
    end
  end
  
  # secure the given block to Company Admin's only (as opposed to System Admins)
  def admin_secure(err_msg = "Only administrators can do this.")
    if current_user.admin?
      yield
    else
      error_redirect err_msg
    end
  end
  
  def sys_admin_secure(err_msg = "Only system admins can do this.")
    if current_user.sys_admin?
      yield
    else
      error_redirect err_msg
    end
  end
  
  # Strips top level parameter keys from the URI query string.  Note, this method
  # does not support nested parameter names (ala "model[attribute]").
  def strip_uri_params uri_string, *keys
    uri = URI.parse uri_string
    begin 
      query_params = Rack::Utils.parse_nested_query(uri.query).except(*keys)
      uri.query = Rack::Utils.build_nested_query(query_params)
    end unless uri.query.blank? || keys.empty?
    # Set the query to nil if it's blank, othewise a dangling "?" is added to the path
    uri.query = nil if uri.query.blank?
    return uri.to_s
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

  # If true (default), legacy javascript files will be included in the html rendered.
  # Override and return false if legacy files are not needed (all angular based pages should return false )
  def legacy_javascripts?
    true
  end

  # Returns true if the user's browser is IE < 9.
  # Relies on the browser gem to make this calculation
  def old_ie_version? 
    return browser.ie? && Integer(browser.version) < 9 rescue true
  end

  private
  
  def set_master_setup
    MasterSetup.current = MasterSetup.get false 
  end

  def force_reset
    if logged_in? && current_user.password_reset
      redirect_to(forced_password_reset_path(current_user))
      return false
    end
  end

  def sortable_search_heading(f_short)
    help.link_to @s_params[f_short][:label], url_for(merge_params(:sf=>f_short,:so=>(@s_sort==@s_params[f_short] && @s_order=='a' ? 'd' : 'a'))) 
  end

  def merge_params(p={})
    params.merge(p).delete_if{|k,v| v.blank?}
  end

  def errors_to_flash(obj, options={})
    if obj.errors.any?
      obj.errors.full_messages.each do |msg|
        add_flash :errors, msg, options
      end
    end
  end

  def has_messages
    errors = flash[:errors]
    notices = flash[:notices]
    return (!errors.nil? && errors.length > 0) || (!notices.nil? && notices.length > 0)
  end

  def add_flash(type,message,options={})
    now = options[:now] || (request.xhr? ? true : false)
    if now
      if flash.now[type].nil?
        flash.now[type] = []
      end
      flash.now[type] << message
    else
      if flash[type].nil?
        flash[type] = []
      end
      flash[type] << message
    end
  end

  def current_user_session
    return @current_user_session if defined?(@current_user_session)
    @current_user_session = UserSession.find
  end

  def current_user
    return @current_user unless @current_user.nil?
    @current_user = current_user_session && current_user_session.record
    if @current_user && @current_user.run_as
      @run_as_user = @current_user
      @current_user = @current_user.run_as
    end
    User.current = @current_user
    @current_user
  end

  def require_user
    unless current_user
      store_location
      add_flash :errors, "You must be logged in to access this page. #{PublicField.first.nil? ? "" : "Public shipment tracking is available below."}"
      redirect_to login_path
      return false
    end
  end

  def store_location
    session[:return_to] = request.fullpath unless request.fullpath.match(/message_count/) 
  end

  def redirect_back_or_default(default)
      redirect_to(session[:return_to] || default)
      session[:return_to] = nil
  end

  def master_company
      return Company.where({ :master => true }).first()
  end

  def set_user_time_zone
      @default_time_zone = Time.zone
      Time.zone = current_user.time_zone if logged_in?
  end

  def logged_in?
      return !current_user.nil?
  end

  def hash_flip(src)
      dest = Hash.new
      src.each {|k,v| dest[v] = k}
      return dest
  end

  def sanitize_params_for_log(p)
    r = {}
    p.each {|k,v| r[k]=v if v.is_a?(String)}
    r
  end
  def model_field_label(model_field_uid) 
    r = ""
    return "" if model_field_uid.nil?
    mf = ModelField.find_by_uid(model_field_uid)
    return "" if mf.nil?
    return mf.label
  end
  def new_relic
    if Rails.env=='production'
      m = MasterSetup.get
      NewRelic::Agent.add_custom_parameters(:uuid=>m.uuid)
      NewRelic::Agent.add_custom_parameters(:system_code=>m.system_code)
      NewRelic::Agent.add_custom_parameters(:user=>current_user.username) unless current_user.nil?
    end
  end
  def prep_model_fields
    ModelField.reload_if_stale
    ModelField.web_mode = true
  end

  def set_legacy_scripts
    @include_legacy_scripts = legacy_javascripts?
  end

  def reset_state_values
    # Try and clear any globals that may retain any unwanted state inside the current the process.
    @current_user = nil
    User.current = nil
    MasterSetup.current = nil
    Time.zone = @default_time_zone
    @include_legacy_scripts = nil
  end
end
