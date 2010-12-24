class ApplicationController < ActionController::Base
    protect_from_forgery
    before_filter :require_user
    before_filter :update_message_count
    before_filter :set_user_time_zone

    helper_method :current_user
    helper_method :master_company
    helper_method :add_flash
    helper_method :has_messages
    helper_method :errors_to_flash
    helper_method :update_message_count
    helper_method :hash_flip
    helper_method :merge_params
    helper_method :sortable_search_heading
    
    def help
        Helper.instance
    end

    class Helper
        include Singleton
        include ActionView::Helpers::TextHelper
        include ActionView::Helpers::UrlHelper
    end

    #subclassed controller must implement secure method that returns searchable object
    def build_search(field_list,default_search,default_sort,default_sort_order='a')
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
        @search = secure.search((@s_search[:field]+'_'+@s_con) => sval)
        @s_sort = field_list[params[:sf]]
        @s_sort = field_list[default_sort] if @s_sort.nil?
        @s_order = default_sort_order
        @s_order = params[:so] if !params[:so].nil? && ['a','d'].include?(params[:so])
        @search.meta_sort = @s_sort[:field]+(@s_order=='d' ? '.desc' : '.asc')
        return @search
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
    
      render :layout => false
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

    
    private
    def sortable_search_heading(f_short)
      help.link_to @s_params[f_short][:label], url_for(merge_params(:sf=>f_short,:so=>(@s_sort==@s_params[f_short] && @s_order=='a' ? 'd' : 'a'))) 
    end

    def merge_params(p={})
        params.merge(p).delete_if{|k,v| v.blank?}
    end

    def update_message_count
        if !current_user.nil?
            @message_count = Message.count(:conditions => ["user_id = #{current_user.id} AND read = ?",false])
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
            add_flash :errors, "You must be logged in to access this page"
            redirect_to login_path
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
end
