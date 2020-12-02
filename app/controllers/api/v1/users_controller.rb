require 'omniauth-google-oauth2'

module Api; module V1; class UsersController < Api::V1::ApiController
  include Clearance::Controller
  skip_around_action :validate_authtoken, only: [:login, :google_oauth2]
  skip_around_action :set_user_settings, only: [:login, :google_oauth2]
  before_action :prevent_clearance_response_cookies

  def login
    # TODO - This really needs account freezing implemented after too many failed attempts
    # within a certain timeframe.  Would be quite easy to do w/ a redis based auto expiring key.
    user = authenticate params
    login_user user
  end

  def me
    render json: {user: current_user.api_hash}
  end

  def enabled_users
    # The "messiness" of this method is primarily due to optimizing it due to it's use on every search screen load...the queries are hand tuned for speed and the json
    # is hand rendered for the same reason
    companies = current_user.company.visible_companies.joins(:users).order("lower(companies.name)").uniq.select(["companies.id", "companies.name"]).to_a
    user_hash = Hash.new do |h, k|
      h[k] = []
    end
    User.enabled.where(company_id: companies.map(&:id)).order("company_id, lower(first_name), lower(last_name)").select([:id, :company_id, :username, :first_name, :last_name]).each do |u|
      user_hash[u.company_id] << {"id" => u.id, "first_name" => u.first_name, "last_name" => u.last_name, "full_name" => u.full_name}
    end
    json = []
    companies.each do |c|
      json << {"company" => {"name" => c.name, "users" => user_hash[c.id]}}
    end

    render :json => json
  end

  def toggle_email_new_messages
    u = current_user
    u.email_new_messages = !u.email_new_messages?
    u.save!
    redirect_to '/api/v1/users/me'
  end

  def google_oauth2
    # What's happening here is the user's device is making a validation request to google to obtain an
    # authtoken.  Their device is then sharing that token with us, which we can then use to
    # validate the token information by finding out the user the token is associated with.
    # The response from google includes the user's email, which we can then use to look up the
    # local user and then login the user.

    # Raise a 404 if the interface isn't set up
    # The client_id / client_secret really should be in secrets when we move to rails 4
    raise ActiveRecord::RecordNotFound unless MasterSetup.test_env? || (Rails.application.config.respond_to?(:google_oauth2_api_login) && Rails.application.config.google_oauth2_api_login[:client_id] &&
                                                Rails.application.config.google_oauth2_api_login[:client_secret])

    access_token = params[:auth_token].presence || params[:access_token]

    user = nil
    if access_token.blank?
      render_error "The access_token parameter was missing."
    else
      strategy = OmniAuth::Strategies::GoogleOauth2.new Rails.application.config.google_oauth2_api_login[:client_id], Rails.application.config.google_oauth2_api_login[:client_secret]
      result = nil
      begin
        result = strategy.client.request(:get, 'https://www.googleapis.com/oauth2/v3/userinfo', params: {access_token: access_token}).parsed.with_indifferent_access
      rescue
        # If the token is bad or old then we'll get an error..we don't really care..just forbid access in this case
      end

      if !result.try(:[], :email).blank?
        # Email address is required to be unique throughout the system..so we can rely on only having a single result
        user = User.where(email: result[:email]).first
      end

      if user
        login_user user
      else
        render_forbidden
      end
    end
  end

  # Change the currently logged in user's password
  # POST: /api/v1/users/change_my_password.json {password: "XXXXX"}
  def change_my_password
    user = current_user
    if user.update_user_password params[:password], params[:password]
      render json: {ok:'ok'}
    else
      if user.errors.size > 0
        render_error user.errors, 406
      else
        render_error "Failed to update password.", 406
      end
    end
  end

  private

    def authenticate params
      # This is here so we don't have to conform to Clearance's expected user data hash format
      User.authenticate(params[:user].try(:[], :username), params[:user].try(:[], :password))
    end

    def login_user user
      sign_in(user) do |status|
        if status.success?
          user.on_successful_login request

          if user.api_auth_token.blank?
            user.api_auth_token = User.generate_authtoken(user)
            user.save!
          end

          render json: {id: user.id, username: user.username, token: user.user_auth_token, full_name: user.full_name}
        else
          render_forbidden
        end
      end
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

    # clobber clearance current_user
    def current_user
      @user
    end
end; end; end;
