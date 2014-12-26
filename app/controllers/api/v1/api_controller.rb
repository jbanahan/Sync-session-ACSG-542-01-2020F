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
    user = current_user
    raise StatusableError.new("You do not have permission to view this module.", 401) unless user.view_module?(core_module)
    page = !params['page'].blank? && params['page'].to_s.match(/^\d*$/) ? params['page'].to_i : 1
    per_page = !params['per_page'].blank? && params['per_page'].to_s.match(/^\d*$/) ? params['per_page'].to_i : 10
    per_page = 50 if per_page > 50
    k = core_module.klass.scoped
    

    #apply search criterions
    search_criterions.each do |sc|
      return unless validate_model_field 'Search', sc.model_field_uid, core_module, user
      k = sc.apply(k)
    end

    #apply sort criterions
    sort_criterions.each do |sc|
      return unless validate_model_field 'Sort', sc.model_field_uid, core_module, user
      k = sc.apply(k)
    end
    k = core_module.klass.search_secure(user,k)
    k = k.paginate(per_page:per_page,page:page)
    r = k.to_a.collect {|obj| obj_to_json_hash(obj)}
    render json:{results:r,page:page,per_page:per_page}
  end

  def render_attachments?
    params[:include] && params[:include].match(/attachments/)
  end
  #add attachments array to root of hash
  def render_attachments obj, hash
    hash['attachments'] = Attachment.attachments_as_json(obj)[:attachments]
  end

  #override this to implement custom finder
  def find_object_by_id id
    core_module.klass.find_by_id params[:id]
  end
  def render_show core_module
    obj = find_object_by_id params[:id]
    raise StatusableError.new("Not Found",404) unless obj && obj.can_view?(current_user)
    render json:{core_module.class_name.underscore => obj_to_json_hash(obj)}
  end

  # generic create method 
  # subclasses must implement the save_object method which takes a hash and should return the object that was saved with any errors set
  def do_create core_module
    obj_name = core_module.class_name.underscore
    ActiveRecord::Base.transaction do
      obj_hash = params[obj_name]
      obj = save_object obj_hash
      if obj.errors.full_messages.blank?
        obj.create_async_snapshot if obj.respond_to?('create_async_snapshot')
      else
        raise StatusableError.new(obj.errors.full_messages.join("\n"), 400)
      end
      render json: {obj_name => obj_to_json_hash(obj)}
    end
  end

  #generic update method
  # subclasses must implement the save_object method which takes a hash and should return the object that was saved with any errors set
  def do_update core_module
    obj_name = core_module.class_name.underscore
    ActiveRecord::Base.transaction do
      obj_hash = params[obj_name]
      raise StatusableError.new("Path ID #{params[:id]} does not match JSON ID #{obj_hash['id']}.",400) unless params[:id].to_s == obj_hash['id'].to_s
      obj = save_object obj_hash
      if obj.errors.full_messages.blank?
        obj.create_async_snapshot if obj.respond_to?('create_async_snapshot')
      else
        raise StatusableError.new(obj.errors.full_messages.join("\n"), 400)
      end
      #call do_render instead of using the in memory object so we can benefit from any special optimizations that the implementing classes may do
      render_show core_module
    end
  end

  #limit list of fields to render to only those that client requested and can see
  def limit_fields field_list
    if !params[:fields].blank?
      field_list = field_list & params[:fields].split(',').collect {|x| x.to_sym}
    end

    user = current_user
    field_list.delete_if {|uid| mf = ModelField.find_by_uid(uid); !mf.user_accessible? || !mf.can_view?(user)}
  end

  #load data into object via model fields
  def import_fields base_hash, obj, core_module
    fields = core_module.model_fields {|mf| mf.user_accessible? && base_hash.has_key?(mf.uid.to_s)}
    
    user = current_user
    fields.each_pair do |uid, mf|
      uid = mf.uid.to_s
      # process_import handles checking if user can edit or if field is read_only?
      # so don't bother w/ that here
      mf.process_import(obj,base_hash[uid], user)
    end
    nil
  end

  #render field for json
  def export_field model_field_uid, obj,opts = {}
    opts = {force_big_decimal_numeric: false}.merge opts
    mf = ModelField.find_by_uid(model_field_uid)
    v = mf.process_export(obj,current_user)
    return "" if v.blank?
    case mf.data_type
    when :integer
      v = v.to_i
    when :decimal, :numeric
      v = BigDecimal(v)
      # The below call (to_f) can result in loss of precision because of the translation to
      # float.  This is done though, so that the value is serialized over the wire 
      # as a javascript numeric instead of a string (as BigDecimal is serialized as).
      # Be very careful if you are expecting precision even amounts w/ a relatively low
      # number of significant digits (or decimal places)
      v = opts[:force_big_decimal_numeric] ? v.to_f : v
    end
    v
  end

  #helper method to get model_field_uids for custom fields
  def custom_field_keys core_module
    core_module.model_fields(current_user) {|mf| mf.custom? }.keys
  end

  def require_admin
    render_forbidden unless User.current.admin?
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
      if request.headers["HTTP_ACCEPT"].match /application\json/
        raise StatusableError.new("Request must include Accept header of 'application/json'.", :not_acceptable)
      end

      if ["POST","PUT"].include?(request.method)  && !(request.headers["CONTENT_TYPE"].match(/application\/json/))
        raise StatusableError.new("Content-Type '#{request.headers["CONTENT_TYPE"]}' not supported.", :not_acceptable)
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
      User.includes(:groups).find_by_username_and_api_auth_token username, auth_token
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

        raise error if Rails.env == 'test'
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

  def validate_model_field field_type, model_field_uid, core_module, user
    mf = ModelField.find_by_uid model_field_uid
    if mf.blank? || !mf.user_accessible || !mf.can_view?(user)
      raise StatusableError.new("#{field_type} field #{model_field_uid} not found.", 400 )
    end
    if mf.core_module != core_module
      raise StatusableError.new("#{field_type} field #{model_field_uid} is for incorrect module.", 400)
    end
    true
  end

end; end; end