module Api; module V1; class ApiController < ActionController::Base
  # disable authlogic for all requests to these controllers
  # we're using our own authtoken based authentication
  skip_filter :activate_authlogic 
  rescue_from StandardError, :with => :error_handler

  around_filter :validate_authtoken
  around_filter :set_user_settings
  before_filter :validate_format

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
      if request.headers["CONTENT_TYPE"] != "application/json"
        raise StatusableError.new("Content-Type '#{request.headers["CONTENT_TYPE"]}' not supported.", :not_acceptable)
      end
    end

    def validate_authtoken
      api_user = nil
      begin
        api_user = authenticate_with_http_token do |token, options|
          # Token should be username:token (username is there to mitigate timing attacks)
          username, auth_token = token.split(":")
          user = User.where(:username => username).first
          if user && user.api_auth_token == auth_token
            user
          else
            nil
          end
        end
      rescue 
        # Invalid authentication tokens will blow up the rails token parser (stupid), we don't really want to hear about this error 
        # since it's the client's fault they didn't set up their request correctly, so just let the api_user check below handle 
        # this as an access denied error
      end

      raise StatusableError.new("Access denied.", :unauthorized) unless api_user

      @user = api_user
      yield
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
end; end; end