require 'yaml'
require 'newrelic_rpm'
require 'open_chain/application_controller_legacy'
require 'open_chain/field_logic'

class ApplicationController < ActionController::Base
  include Clearance::Controller
  include OpenChain::ApplicationControllerLegacy
  include RequestLoggingSupport
  include AuthTokenSupport
  
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception
  
  # This is Clearances default before filter...we already handle its use cases in require_user more to our liking
  skip_before_filter :require_login
  before_filter :chainio_redirect
  before_filter :prep_model_fields
  before_filter :new_relic
  before_filter :set_master_setup
  before_filter :require_user
  before_filter :prep_exception_notifier
  before_filter :portal_redirect
  before_filter :set_user_time_zone
  before_filter :log_request
  before_filter :log_run_as_request
  before_filter :log_last_request_time
  before_filter :force_reset
  before_filter :set_legacy_scripts
  before_filter :set_x_frame_options_header
  before_filter :set_page_title

  helper_method :master_company
  helper_method :add_flash
  helper_method :has_messages
  helper_method :errors_to_flash
  helper_method :hash_flip
  helper_method :merge_params
  helper_method :sortable_search_heading
  helper_method :master_setup
  helper_method :run_as_user

  after_filter :reset_state_values
  after_filter :set_csrf_cookie
  after_filter :set_auth_token_cookie

  def set_page_title
    @page_title = "VFI Track"
  end

  # render generic json error message
  def render_json_error message, response_code=500
    render json: {error:message}, status: response_code
    true
  end

  def prep_exception_notifier
    #prep for exception notification
    data = {
      server_name: InstanceInformation.server_name,
      server_role: InstanceInformation.server_role
    }
    data[:user] = current_user if current_user
    request.env["exception_notifier.exception_data"] = data
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

  #controller action to display generic history page
  def history
    p = root_class.find params[:id]
    action_secure(p.can_view?(current_user),p,{:verb => "view",:module_name=>"item",:lock_check=>false}) {
      @base_object = p
      @snapshots = p.entity_snapshots.order("entity_snapshots.id DESC").paginate(:per_page=>5,:page => params[:page])
      render 'shared/history'
    }
  end

  def dump_request
    if current_user.sys_admin?
      output = "REQUEST FROM IP: #{request.remote_ip}\n\nHEADERS\n========================\n\n"
      http_envs = {}.tap do |envs|
        request.headers.each do |key, value|
          # So this is kinda weird...rails (rack?) makes all the HTTP headers capitalized
          envs[key] = value if key[0] == key[0].to_s.upcase
        end
      end
      http_envs.each_pair {|k, v| output += "#{k}: #{v}\n------------------------\n"}
      output += "PARAMS\n========================\n"
      out = {}
      params.each { |k, v| 
        if v.is_a? String
          out[k] = v
        else
          out[k] = "[extracted]"
        end
      }
      output += out.to_s
      
      render plain: output
    else
      raise ActionController::RoutingError.new('Not Found')
    end
  end

  def error_redirect(message=nil)
    add_flash :errors, message unless message.nil?
    target = request.referrer ? request.referrer : "/"
    target = params[:redirect_to].blank? ? target : validate_redirect(params[:redirect_to])
    redirect_to target
  end

  def action_secure(permission_check, obj, options={})
    err_msg = nil
    opts = {
      lock_check: true,
      verb: "edit",
      lock_lambda: lambda {|o| o.respond_to?(:locked?) && o.locked?},
      module_name: "object",
      # Basically, by default, we won't lock objects on a get request
      yield_in_db_lock: !request.get?
    }.merge(options)

    err_msg = "You do not have permission to #{opts[:verb]} this #{opts[:module_name]}." unless permission_check
    err_msg = "You cannot #{opts[:verb]} #{"aeiou".include?(opts[:module_name].slice(0,1)) ? "an" : "a"} #{opts[:module_name]} with a locked company." if opts[:lock_check] && opts[:lock_lambda].call(obj)
    if err_msg.present?
      opts[:json] ? (render_json_error err_msg) : (error_redirect err_msg)
    else
      # We can only db_lock active record objects and only those that are actually persisted
      if opts[:yield_in_db_lock] && (obj.is_a?(ActiveRecord::Base) && obj.persisted?)
        Lock.db_lock(obj) do 
          yield
        end
      else
        yield
      end
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

  def send_excel_workbook workbook, filename
    spreadsheet = StringIO.new
    workbook.write spreadsheet
    send_data spreadsheet.string, :filename => filename, :type => :xls
  end

  def send_builder_data builder, filename_prefix
    output = StringIO.new
    builder.write output
    output.rewind
    send_data output.read, filename: "#{filename_prefix}.#{builder.output_format}", type: builder.output_format.to_sym
  end

  def current_user
    distribute_reads do
      # Clearance controller defines current_user method, we need to add in run_as handling here ourselves
      user = super
      if user
        # Preload the user's groups - since their almost certainly going to be used for access control
        # at some point in the request chain (use length sincce that forces the association to load, but will essentially
        # be a no-op if they're already loaded).
        user.groups.length
        if user.run_as
          @run_as_user = user
          user = user.run_as
          user.groups.length
        end
      end

      user
    end
  end

  # If the current user is running as someone else, returns the REAL user behind the curtain.
  # Returns nil if user isn't currently running as someone else
  def run_as_user
    return nil unless defined?(@run_as_user)
    @run_as_user
  end

  def validate_redirect redirect
    # This is a simple helper method to validate that a redirect path is going back to the domain name configured 
    # for this instance.
    uri_redirect = URI(redirect)

    # We'll allow redirects if there are no hosts...this happens in cases where the path doesn't include the full domain
    # and is treated like a relative path -> "/controller/1"
    raise "Illegal Redirect" unless uri_redirect.host.blank? || URI("https://#{MasterSetup.get.request_host}").host == uri_redirect.host
    redirect
  end

  protected
  def verified_request?
    # Angular uses the header X-XSRF-Token (rather than rails' X-CSRF-Token default), just account for that
    # rather than making config modifications to our angular apps (since we'd have to update several different files
    # rather than just this single spot)
    super || valid_authenticity_token?(session, request.headers['X-XSRF-Token'])
  end

  private

  def set_master_setup
    MasterSetup.current = MasterSetup.get false
  end

  def force_reset
    if signed_in? && current_user.password_reset
      # Basically, we're just going to redirect the user to the standard password resets page using the
      # clearance forgot password functionality

      # The forgot password call just generates a confirmation token which is used by the controller to determine
      # which user is resetting their password
      current_user.forgot_password!
      add_flash(:warning, "Your password has expired. Please select a new password.") if current_user.password_expired
      redirect_to edit_password_reset_path current_user.confirmation_token
      return false
    end
  end

  def sortable_search_heading(f_short)
    fa = (params[:so]=='a' ? "fa-chevron-up" : "fa-chevron-down")
    visible = (params[:sf] == f_short) ? "visible" : "hidden"

    arrow = "<span class=\"fa #{fa}\" style=\"visibility: #{visible}; margin-right: .5em;\"></span>"
    link = help.link_to @s_params[f_short][:label], url_for(merge_params(:sf=>f_short,:so=>(@s_sort==@s_params[f_short] && @s_order=='a' ? 'd' : 'a')))
    (arrow + link).html_safe
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

  def has_errors?
    !flash[:errors].nil? && flash[:errors].length > 0
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

  def require_user
    cu = current_user
    if cu && User.access_allowed?(cu)
      User.current = cu
      @require_user_run = true
    else
      respond_to do |format|
        format.any(:js, :json, :xml) { head :unauthorized }
        format.any {
          # If we had a user that signed in and was disabled, we need to log them out as well, otherwise the login page will see the login and try
          # to redirect, which'll bring us back here, and cause a redirect loop
          if cu
            sign_out
          end

          store_location
          add_flash :errors, "You must be logged in to access this page. #{PublicField.first.nil? ? "" : "Public shipment tracking is available below."}"
          redirect_to login_path
        }
      end
    end
  end

  def log_last_request_time
    if current_user
      # Only bother updating the last request at if it's more than a minute old
      now = Time.zone.now
      last_request = current_user.last_request_at
      if last_request.nil? || (last_request < (now - 1.minute))
        updates = {last_request_at: now}

        # We also want to update the active_days attribute if the date from the last request and the current date don't match
        # We're calculating this by when the actual date changes over NOT if the request has been 24 hours since the previous request
        if last_request.nil? || last_request.to_date != now.to_date
          updates[:active_days] = (current_user.active_days.to_i + 1)
        end

        # We want this to be as fast as possible and not set timestamps, so don't do validations, or anything else
        # Rails 4 can use the #update_columns method to achieve this effect..rails 3 has to do it a little more funkily
        User.where(id: current_user.id).update_all updates
      end
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
    unless current_user.try(:time_zone).blank?
      Time.zone = current_user.time_zone
    end
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
    return "" if model_field_uid.nil?
    mf = ModelField.find_by_uid(model_field_uid)
    return mf.label
  end
  def new_relic
    if Rails.env.production?
      m = MasterSetup.get
      attrs = {uuid: m.uuid, system_code: m.system_code}
      attrs[:user] = current_user.username unless current_user.nil?
      NewRelic::Agent.add_custom_attributes attrs
    end
  end
  def prep_model_fields
    ModelField.reload_if_stale
    ModelField.disable_stale_checks = true
  end

  def set_legacy_scripts
    @include_legacy_scripts = legacy_javascripts?
  end

  def reset_state_values
    # Try and clear any globals that may retain any unwanted state inside the current the process.
    User.current = nil
    MasterSetup.current = nil
    Time.zone = @default_time_zone
    @include_legacy_scripts = nil
  end

  def set_x_frame_options_header
    response.headers['X-Frame-Options'] = 'SAMEORIGIN'
  end

  def set_csrf_cookie
    # Angular will pick up this cookie value and add it to every ajax request, which allows us to then
    # utilize the rails forgery protection.
    if protect_against_forgery?
      cookies['XSRF-TOKEN'] = {value: form_authenticity_token, secure: Rails.application.config.use_secure_cookies}
    end
  end

  def portal_redirect
    return unless @require_user_run
    prp = current_user.portal_redirect_path
    redirect_to prp unless prp.blank? || request.path.downcase.index(prp.downcase)==0
  end
end
