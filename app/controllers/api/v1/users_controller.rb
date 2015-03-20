module Api; module V1; class UsersController < Api::V1::ApiController
  include Clearance::Controller
  skip_around_filter :validate_authtoken, only: :login
  skip_around_filter :set_user_settings, only: :login
  before_filter :prevent_clearance_response_cookies

  def login
    # TODO - This really needs account freezing implemented after too many failed attempts 
    # within a certain timeframe.  Would be quite easy to do w/ a redis based auto expiring key.
    user = authenticate params
    sign_in(user) do |status|
      if status.success?
        user.on_successful_login request
        render json: {username: current_user.username, token: current_user.api_auth_token}
      else
        render_forbidden
      end
    end
  end

  def authenticate params
    # This is here so we don't have to conform to Clearance's expected user data hash format
    User.authenticate(params[:user].try(:[], :username), params[:user].try(:[], :password))
  end

  def prevent_clearance_response_cookies
    session = clearance_session
    
    if session
      # Override these methods to prevent clearance from writing cookies to the response
      # We don't want these for the API.
      def session.add_cookie_to_headers(h); nil; end
      def session.cookies; {}; end
    end

    true
  end
end; end; end;