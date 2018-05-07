class UserSessionsController < ApplicationController
  skip_before_filter :require_user, :only => [:create, :new, :destroy, :create_from_omniauth]
  skip_before_filter :force_reset, :only => [:destroy]
  protect_from_forgery :except => [:create, :create_from_omniauth]

  def index
    if current_user
      redirect_to root_path
    else
      redirect_to new_user_session_path
    end
  end

  def new
    @no_action_bar = true
    if current_user
      redirect_to root_path
    else
      render layout: false
    end
  end

  def create
    remember_me

    user = authenticate(params)
    locked_password = locked_password?(user)

    # This call runs the clearance sign_in "guards" which runs business logic validations
    # to check if user is allowed to login (.ie user isn't locked, disabled etc)
    handle_sign_in(user, locked_password: locked_password)
  end

  def create_from_omniauth
    # The omniauth.auth env object is set by the omniauth rack middleware, set up
    # in the omniauth.rb initializer.
    # provider request param comes from the url segment /auth/:provider/callback
    user_info = User.from_omniauth(params[:provider], request.env["omniauth.auth"])

    if user_info[:user]
      handle_sign_in(user_info[:user])
    else
      session.delete :user_id
      if user_info[:errors]
        user_info[:errors].each {|e| add_flash :errors, e}
      end

      redirect_to login_path
    end
  end

  def handle_sign_in(user, opts={})
    sign_in(user) do |status|
      # I don't know why user would be nil here but it is sometimes (concurrency issue perhaps or something in clearance maybe?), so just
      # handle that like it was a bad login.
      if user && !opts[:locked_password] && status.success?
        session[:user_id] = user.id
        user.on_successful_login request
        respond_to do |format|
          format.html { redirect_back_or_default(:root) }
          format.json { head :ok }
        end
      else
        session.delete :user_id
        if opts[:locked_password]
          error = "Your password is currently locked because you failed to log in correctly 5 times.  Please click the Forgot your VFI Track password? link below to reset your password."
        else
          error = "Your login was not successful."
        end
        respond_to do |format|
          format.html {
            add_flash :errors, error
            redirect_to new_user_session_path
          }
          format.json { render :json => {"errors"=>[error]} }
        end
      end
    end
  end

  # DELETE /user_sessions/1
  def destroy
    sign_out
    cookies.delete(:remember_me)
    add_flash :notices, "You are logged out. Thanks for visiting."
    redirect_to new_user_session_path
  end

  private

    def locked_password?(user)
      return false if user.blank?

      user.password_locked || user.failed_logins > 4
    end

    def remember_me
      # Clearance (due to wanting a "clean codebase"), removed the option to
      # allow for the remember me cookie to be just a plain session cookie (ie. deleted when the browser is closed).
      # This is what we actually want in the default case (security concerns, blah, blah).
      # The only real way to implement this is via the cookie expiration callback Clearance uses, which has access
      # to the browser cookies.  Therefore, we can set a cookie here if the user wants to be remembered and then
      # check in the callback for it and not allow the remember_token cookie to expire.
      if params[:remember_me] && !Rails.application.config.disable_remember_me
        # We don't use SSL in development, so make sure we don't use secure cookies there, otherwise,
        # remember me won't work.
        cookies.permanent[:remember_me] = {value: "", secure: Rails.application.config.use_secure_cookies, httponly: true}
      else
        cookies.delete(:remember_me)
      end
    end

    def authenticate params
      # This is primarily here so we don't have to change anything on the login screen after moving
      # to clearance from Authlogic (since we do have the Imaging Archiver project using these params I don't want to change)
      User.authenticate(params[:user_session].try(:[], :username), params[:user_session].try(:[], :password))
    end
end
