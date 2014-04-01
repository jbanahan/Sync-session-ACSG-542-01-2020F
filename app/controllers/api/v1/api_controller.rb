require 'open_chain/api/api_entity_jsonizer'

module Api; module V1; class ApiController < ActionController::Base
  # disable authlogic for all requests to these controllers
  # we're using our own authtoken based authentication
  skip_filter :activate_authlogic 
  rescue_from Exception, :with => :error_handler

  around_filter :validate_authtoken
  around_filter :set_user_settings
  before_filter :validate_format

  attr_reader :jsonizer

  def initialize jsonizer = OpenChain::Api::ApiEntityJsonizer.new
    @jsonizer = jsonizer
  end

  def render_error errors, status = :not_found
    e = errors.is_a?(Enumerable) ? errors : [errors]
    render json: {:errors => e}, status: status
  end

  def show_module mod
    render_obj mod.find params[:id]
  end

  def render_obj obj
    raise ActiveRecord::RecordNotFound unless obj

    if obj.can_view? User.current
      render json: jsonizer.entity_to_json(User.current, obj, parse_model_field_param_list)
    else
      render_error "Not Found.", :not_found
    end
  end

  def render_model_field_list core_module
    if core_module.view? User.current
      render json: jsonizer.model_field_list_to_json(User.current, core_module)
    else
      render_error "Not Found.", :not_found
    end
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
      raise StatusableError.new("Format #{params[:format].to_s} not supported.", :not_acceptable) if request.format != Mime::JSON
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
      end
    end

    def parse_model_field_param_list
      uids = params[:mf_uids]

      # Depending on how params are sent, the uids could be an array or a string
      # query string like "mf_uid[]=uid&mf_uid[]=uid2" will result in an array (rails takes care of this for us
      # so do most other web application frameworks and lots of tools autogenerate parameters like this so we'll support it)
      # query string like "mf_uid=uid,uid2,uid2" results in a string
      unless uids.is_a?(Enumerable) || uids.blank?
        uids = uids.split(/[,~]/).collect {|v| v.strip}
      end

      uids = [] if uids.blank?

      uids 
    end

end; end; end