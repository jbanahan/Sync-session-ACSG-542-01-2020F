module Api; module V1; class ApiController < ActionController::Base
  rescue_from StandardError, :with => :error_handler

  before_filter :validate_format
  around_filter :validate_authtoken
  around_filter :set_user_settings

  def current_user
    @user
  end

  def render_forbidden message = "Access denied."
    render_error message, :forbidden
  end

  def require_admin
    render_forbidden unless User.current.admin?
  end

  def render_error errors, status = :internal_server_error
    e = nil
    if errors.is_a?(ActiveModel::Errors)
      e = errors.full_messages
    elsif errors.respond_to? :each
      e = []
      errors.each {|err| e << err.to_s}
    else
      e = [errors.to_s]
    end
    render json: {:errors => e}, status: status
  end

  def action_secure(permission_check, obj, options={})
    err_msg = nil
    opts = {
      :lock_check => true,
      :verb => "edit",
      :lock_lambda => lambda {|o| o.respond_to?(:locked?) && o.locked?},
      :module_name => "object"}.merge(options)
    err_msg = "You do not have permission to #{opts[:verb]} this #{opts[:module_name]}." unless permission_check
    err_msg = "You cannot #{opts[:verb]} #{"aeiou".include?(opts[:module_name].slice(0,1)) ? "an" : "a"} #{opts[:module_name]} with a locked company." if opts[:lock_check] && opts[:lock_lambda].call(obj)
    unless err_msg.nil?
      render_forbidden err_msg
    else
      yield
    end
  end

  # use this as a prepend_before_filter to accept CSV format for a route
  #  it has to be prepended because it needs to run before validate_format
  def allow_csv
    @allow_csv = true
  end

  private
    def validate_format
      return if @allow_csv && request.format.csv?
      accept = request.headers["HTTP_ACCEPT"]
      if accept.blank? || !accept.match(/application\/json/)
        raise StatusableError.new("Request must include Accept header of 'application/json'.", :not_acceptable)
      end

      content_type = request.headers["CONTENT_TYPE"]
      content_type = "" if content_type.nil?
      if ["POST","PUT"].include?(request.method)  && !content_type.match(/application\/json/)
        raise StatusableError.new("Content-Type '#{content_type}' not supported.", :not_acceptable)
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
      User.includes(:groups).find_by_username_and_api_auth_token username, (auth_token ? auth_token : "PREVENTS_ACCIDENTAL_NULL_TOKEN_USAGE")
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
        render_error "Not Found", :not_found
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

end; end; end
