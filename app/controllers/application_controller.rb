class ApplicationController < ActionController::Base
    require 'yaml'

    protect_from_forgery
    before_filter :require_user
    before_filter :check_tos
    before_filter :update_message_count
    before_filter :set_user_time_zone
    before_filter :log_request
    before_filter :set_cursor_position

    helper_method :current_user
    helper_method :master_company
    helper_method :add_flash
    helper_method :has_messages
    helper_method :errors_to_flash
    helper_method :update_message_count
    helper_method :hash_flip
    helper_method :merge_params
    helper_method :sortable_search_heading
    helper_method :master_setup
   
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
    end

  def master_setup
    MasterSetup.first
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

  def advanced_search(core_module)
    @core_module = core_module
    @saved_searches = SearchSetup.for_module(@core_module).for_user(current_user)
    @current_search = get_search_to_run
    if @current_search.user != current_user
      error_redirect "You cannot run a search that is assigned to a different user."
    else
      begin
        render_search_results
      rescue Exception => e
        logger.error $!, $!.backtrace
        OpenMailer.send_custom_search_error(@current_user, e.message).deliver
        add_flash :errors, "There was an error running your search.  We have replaced it with a different search so you can continue working."
        @current_search.destroy
        @current_search = get_search_to_run
        render_search_results
      end
    end    
  end

  
    def update_custom_fields(customizable_parent, customizable_parent_params=nil) 
        cpp = customizable_parent_params.nil? ? params[(customizable_parent.class.to_s.downcase+"_cf").intern] : customizable_parent_params
        pass = true
        unless cpp.nil?
          cpp.each do |k,v|
            definition_id = k.to_s
            cd = CustomDefinition.find(definition_id)
            cv = customizable_parent.get_custom_value cd
            cv.value = v
            cv.save
            pass = false unless cv.errors.empty?
            errors_to_flash cv
          end
        end
        pass
    end
    
    def update_status(statusable)
      current_status = statusable.status_rule_id
      statusable.set_status
      statusable.save if current_status!=statusable.status_rule_id
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
        @s_con = params[:c].nil? ? 'eq' : params[:c]
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
    
    def render_csv(filename = 'download.csv')
      if request.env['HTTP_USER_AGENT'] =~ /msie/i
        headers['Pragma'] = 'public'
        headers["Content-type"] = "text/plain" 
        headers['Cache-Control'] = 'no-cache, must-revalidate, post-check=0, pre-check=0'
        headers['Content-Disposition'] = "attachment; filename=\"#{filename}\"" 
        headers['Expires'] = "0" 
      else
        headers["Content-Type"] ||= 'text/csv'
        headers["Content-Disposition"] = "attachment; filename=\"#{filename}\"" 
      end
    
      render :text => CsvMaker.new.make(@current_search,@results) 
    end

    def error_redirect(message)
        add_flash :errors, message
        redirect_to request.referrer
    end
    
  def action_secure(permission_check, obj, options={})
    err_msg = nil
    opts = {
      :lock_check => true, 
      :verb => "edit", 
      :lock_lambda => lambda {|obj| obj.locked?},
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
  
  #get the next object from the most recently run search 
  def next_object(move=true)
    sr = search_run
    n = sr.next_object
    if move && !n.nil?
      sr.move_forward
      sr.save
    end
    n
  end

  #get the previous object from the most recenty run search
  def previous_object(move=true)
    sr = search_run
    n = sr.previous_object
    if move && !n.nil?
      sr.move_back
      sr.save
    end
    n
  end

  #action to show next object from search result (supporting next button)
  def show_next
    n = next_object
    if n.nil?
      error_redirect "No more items in the search list."
    else
      redirect_to n
    end
  end
  
  #action to show previous object from search result (supporting previous button)
  def show_previous
    n = previous_object
    if n.nil?
      error_redirect "No more items in the search list."
    else
      redirect_to n
    end
  end

  #add this redirect at the end of your update controller action to support next & previous buttons
  def redirect_update base_object, action="edit"
    target = nil
    if params[:c_next]
      target = next_object
      add_flash :errors, "No more items in the search list." if target.nil?
    elsif params[:c_previous]
      target = previous_object
      add_flash :errors, "No more items in the search list." if target.nil?
    end
    if target
      redirect_to send("#{action}_#{base_object.class.to_s.underscore}_path",target)
    else
      redirect_to(@product) 
    end
  end
  
  def get_search_to_run
    s = nil
    s = SearchSetup.for_module(@core_module).for_user(current_user).where(:id=>params[:sid]).first unless params[:sid].nil?
    s = SearchSetup.for_module(@core_module).for_user(current_user).order("last_accessed DESC").first if s.nil?
    s = @core_module.make_default_search current_user if s.nil?
    s
  end
  
  def search_run
    return nil unless self.respond_to?('root_class') || @core_module
    @core_module = CoreModule.find_by_class_name self.root_class.to_s unless @core_module
    ss = get_search_to_run
    sr = ss.search_run
    sr = ss.create_search_run if sr.nil?
    sr
  end

  private
  def set_cursor_position
    cp = params[:c_pos]
    return unless cp && cp.match(/^[0-9]*$/)
    sr = search_run
    return unless sr
    sr.position = cp.to_i
    sr.save
  end

  def render_search_results
      if @current_search.name == "Extreme latest" && current_user.sys_admin?
        raise "Extreme latest goes boom!!"
      end
      
      @results = @current_search.search
      respond_to do |format| 
        format.html {
          @current_search.touch(true)
          @results = @results.paginate(:per_page => 20, :page => params[:page]) 
          render :layout => 'one_col'
        }
        format.csv {
          @results = @results.where("1=1")
          render_csv("#{@core_module.label}.csv")
        }
        format.json {
          @results = @results.paginate(:per_page => 20, :page => params[:page])
          rval = []
          cols = @current_search.search_columns.order("rank ASC")
          GridMaker.new(@results,cols,@current_search.search_criterions,@current_search.module_chain).go do |row,obj| 
            row_data = []
            row.each do |c|
              row_data << c.to_s
            end
            rr = ResultRecord.new
            rr.data=row_data
            rr.url=url_for obj
            rval << rr
          end
          sr = SearchResult.new
          sr.columns = []
          cols.each {|col|
            sr.columns << model_field_label(col.model_field_uid) 
          }
          sr.records = rval
          sr.name = @current_search.name
          render :json => sr
        }
        format.xls {
          book = XlsMaker.new.make(@current_search,@results.where("1=1")) 
          spreadsheet = StringIO.new 
          book.write spreadsheet 
          send_data spreadsheet.string, :filename => "#{@current_search.name}.xls", :type =>  "application/vnd.ms-excel"
        }
      end
  end
    def sortable_search_heading(f_short)
      help.link_to @s_params[f_short][:label], url_for(merge_params(:sf=>f_short,:so=>(@s_sort==@s_params[f_short] && @s_order=='a' ? 'd' : 'a'))) 
    end

    def merge_params(p={})
        params.merge(p).delete_if{|k,v| v.blank?}
    end

    def update_message_count
        if !current_user.nil?
            @message_count = Message.count(:conditions => ["user_id = #{current_user.id} AND viewed = ?",false])
        end
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
        return @current_user if defined?(@current_user)
        @current_user = current_user_session && current_user_session.record
    end

    def require_user
      unless current_user
        store_location
        add_flash :errors, "You must be logged in to access this page. #{PublicField.first.nil? ? "" : "Public shipment tracking is available below."}"
        redirect_to login_path
        return false
      end
    end

    def check_tos
      if current_user && 
        (current_user.tos_accept.nil? || 
        current_user.tos_accept < TERMS[:privacy] ||
        current_user.tos_accept < TERMS[:terms])
        redirect_to "/show_tos"
        return false
      end
    end


    def store_location
      session[:return_to] = request.request_uri
    end

    def redirect_back_or_default(default)
        redirect_to(session[:return_to] || default)
        session[:return_to] = nil
    end

    def master_company
        return Company.where({ :master => true }).first()
    end

    def set_user_time_zone
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
end
