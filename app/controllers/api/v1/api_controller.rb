module Api; module V1; class ApiController < ActionController::Base
  rescue_from StandardError, :with => :error_handler

  before_filter :validate_format
  around_filter :validate_authtoken
  around_filter :set_user_settings

  
  def current_user
    @user 
  end
  def render_forbidden
    render_error "Access denied.", :unauthorized
  end

  def render_error errors, status = :not_found
    e = nil
    if errors.respond_to? :each
      e = []
      errors.each {|err| e << err.to_s}
    else
      e = [errors.to_s]
    end
    render json: {:errors => e}, status: status
  end
  
  def render_search core_module
    raise StatusableError.new("You do not have permission to view this module.", 401) unless current_user.view_module?(core_module)
    page = !params['page'].blank? && params['page'].to_s.match(/^\d*$/) ? params['page'].to_i : 1
    per_page = !params['per_page'].blank? && params['per_page'].to_s.match(/^\d*$/) ? params['per_page'].to_i : 10
    per_page = 50 if per_page > 50
    k = core_module.klass.scoped
    
    #apply search criterions
    search_criterions.each do |sc|
      return unless validate_model_field 'Search', sc.model_field_uid, core_module
      k = sc.apply(k)
    end

    #apply sort criterions
    sort_criterions.each do |sc|
      return unless validate_model_field 'Sort', sc.model_field_uid, core_module
      k = sc.apply(k)
    end
    k = core_module.klass.search_secure(current_user,k)
    k = k.paginate(per_page:per_page,page:page)
    r = k.to_a.collect {|obj| obj_to_json_hash(obj)}
    render json:{results:r,page:page,per_page:per_page}
  end

  def render_show core_module
    obj = core_module.klass.find_by_id params[:id]
    raise StatusableError.new("Not Found",404) unless obj && obj.can_view?(current_user)
    render json:{core_module.class_name.underscore => obj_to_json_hash(obj)}
  end

  #helper method to get model_field_uids for custom fields
  def custom_field_keys core_module
    core_module.model_fields.keys.collect {|k| k.to_s.match(/\*cf_/) ? k : nil}.compact
  end
  
  class StatusableError < StandardError
    attr_accessor :http_status, :errors

    def initialize errors = [], http_status = :forbidden
      # Allow for simple case where we pass a single error message string
      @errors = errors.is_a?(String) ? [errors] : errors
      @http_status = http_status
      super(@errors.first)
    end
  end

  private
    def validate_format
      if request.headers["HTTP_ACCEPT"] != "application/json"
        raise StatusableError.new("Request must include Accept header of 'application/json'.", :not_acceptable)
      end

      if ["POST","PUT"].include?(request.method)  && !(request.headers["CONTENT_TYPE"].match(/application\/json/))
        raise StatusableError.new("Content-Type '#{request.headers["CONTENT_TYPE"]}' not supported.", :not_acceptable)
      elsif !(["POST", "GET", "PUT"].include?(request.method))
        raise StatusableError.new("Request Method '#{request.method}' not supported.", :not_acceptable)
      end
    end

    def validate_authtoken
      api_user = nil
      begin
        api_user = authenticate_with_http_token do |token, options|
          # Token should be username:token (username is there to mitigate timing attacks)
          user_from_token token
        end
      rescue 
        # Invalid authentication tokens will blow up the rails token parser (stupid), we don't really want to hear about this error 
        # since it's the client's fault they didn't set up their request correctly, so just let the api_user check below handle 
        # this as an access denied error
      end
      if api_user.nil?
        t = cookies['AUTH-TOKEN']
        api_user = user_from_token t unless t.blank?
      end

      raise StatusableError.new("Access denied.", :unauthorized) unless api_user

      @user = api_user
      yield
    end
    def user_from_token t
      username, auth_token = t.split(":")
      User.find_by_username_and_api_auth_token username, auth_token
    end

    def set_user_settings
      #@user is set by the authtoken handler which runs prior to this
      User.current = @user

      # Set the current user into our notifier data so we know which user's
      # request may have caused an error if we get exceptions from the request.
      request.env["exception_notifier.exception_data"] = {
        :user =>  @user
      }

      default_tz = Time.zone
      Time.zone = User.current.time_zone
      begin
        yield
      ensure
        User.current = nil
        Time.zone = default_tz
      end
    end

    def error_handler error
      # Rails makes it a bit of a pain in the butt to use custom exception handling for json requests, 
      # so we have this handler.  But it doesn't propagate out the exceptions so that our notififier
      # is called, so we'll manually handle that below.
      if error.is_a?(StatusableError)
        render_error error.errors, error.http_status
      elsif error.is_a?(ActiveRecord::RecordNotFound)
        render_error "Not Found.", :not_found
      else
        render_error error.message, :internal_server_error

        # This is kind of digging into the bowels of ExceptionNotifier but it's really straightforward and the
        # benefit of getting at the request params in the notifications from this gem are just too good to pass up.
        if ExceptionNotifier.notify_exception(error, :env=>request.env)
          request.env['exception_notifier.delivered'] = true
        end

        # This is basically just copied from how Rails logs exceptions in action dispatch
        message = "\n#{error.class} (#{error.message}):\n"
        message << "  " << error.backtrace.join("\n  ")
        Rails.logger.error "#{message}\n\n"
      end
    end


  def search_criterions
    groups = {}
    params.each do |k,v|
      kstr = k.to_s
      case kstr
      when /^sid\d+$/
        num = kstr.sub(/sid/,'').to_i
        groups[num] ||= {}
        groups[num]['field_id'] = v
      when /^sop\d+$/
        num = kstr.sub(/sop/,'').to_i
        groups[num] ||= {}
        groups[num]['operator'] = v
      when /^sv\d+$/
        num = kstr.sub(/sv/,'').to_i
        groups[num] ||= {}
        groups[num]['value'] = v
      end
    end
    r = []
    groups.each do |k,v|
      r << SearchCriterion.new(model_field_uid:v['field_id'],operator:v['operator'],value:v['value'])
    end
    r
  end

  def sort_criterions
    groups = {}
    params.each do |k,v|
      kstr = k.to_s
      case kstr
      when /^oid\d+$/
        num = kstr.sub(/oid/,'').to_i
        groups[num] ||= {}
        groups[num]['field_id'] = v
      when /^oo\d+$/
        num = kstr.sub(/oo/,'').to_i
        groups[num] ||= {}
        groups[num]['order'] = v
      end
    end
    r = []
    groups.keys.sort.each do |k|
      v = groups[k]
      r << SortCriterion.new(model_field_uid:v['field_id'],descending:v['order']=='D')
    end
    r
  end

  def validate_model_field field_type, model_field_uid, core_module
    mf = ModelField.find_by_uid model_field_uid
    if mf.nil?
      raise StatusableError.new("#{field_type} field #{model_field_uid} not found.", 400 )
      return false
    end
    if mf.core_module != core_module
      raise StatusableError.new("#{field_type} field #{model_field_uid} is for incorrect module.", 400)
      return false
    end
    return true
  end

end; end; end