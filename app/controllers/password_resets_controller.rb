class PasswordResetsController < ApplicationController
  before_action :load_user_using_perishable_token, :only => [:edit, :update]
  skip_before_action :require_user
  skip_before_action :force_reset

  def create
    @user = User.find_by(email: params[:email])
    if @user
      if @user.disallow_password?
        # For security purposes, the text of this message was updated to match the text displayed when an email
        # does not match to a user.  While this doesn't necessarily make sense for cases where a user does not have
        # a password-enabled login, it is safer to not present a distinct message here.
        add_flash :notices, password_reset_message
      else
        @user.delay.deliver_password_reset_instructions!
        # For security purposes, the text of this message was updated to match the text displayed when an email
        # does not match to a user.
        add_flash :notices, password_reset_message
        @user.update_attribute(:forgot_password, true)
      end
    else
      # This originally added an error message indicating that the user/email was bogus.  That was a security
      # issue: a malicious party could very easily determine whether an email address was connected to an accounts.
      # Consequently, whether the user exists or not, the same message is displayed.
      add_flash :notices, password_reset_message
    end
    redirect_to new_user_session_path
  end

  def edit
  end

  def update
    success = false
    current_password_valid = false

    if params[:user][:current_password].present?
      current_password_valid = @user.authenticated?(@user.password_salt, params[:user][:current_password])
    end

    if @user.forgot_password.present? || current_password_valid || @user.password_locked || !@user.password_expired
      if @user.update_user_password params[:user][:password], params[:user][:password_confirmation]
        @user.password_reset = false
        @user.save!
        # Have to actually sign in the user here via clearance to set their remember token
        sign_in(@user) do |status|
          success = status.success?
        end
      end
    elsif @user.password_expired && !current_password_valid
      success = false
      if params[:user][:current_password].present?
        @user.errors.add(:current_password, 'is invalid')
      else
        @user.errors.add(:current_password, 'is required to change password')
      end
    end

    if success
      @user.on_successful_login request
      add_flash :notices, "Password successfully updated"
      redirect_to root_url
    else
      errors_to_flash @user, now: true
      render :action => :edit
    end
  end

  private
    def load_user_using_perishable_token
      unless @user
        # This method used to also fall back to using the user's id to find by, this is very insecure because user id's are easily guessed since they're
        # a numerical sequence.  So, having a lookup on id here effectively provides a means for DOS'ing user accounts - changing random passwords.  The lookups need to be
        # non-deterministic, which is what perishable token attempts to be.

        # Make sure we can't pass a blank token and return a random user
        @user = User.where("confirmation_token <> '' AND confirmation_token IS NOT NULL AND confirmation_token = ?", params[:id]).first

        unless @user
          add_flash :errors, "We're sorry, but we could not locate your account.  Please retry resetting your password from the login page."
          # There's a case here where the user may click a password reset link (probably from an old email) while they already have a live session...probably thinking they
          # can use the password as a shortcut for resetting their password - which doesn't work.  So, we'll log the user out and then redirect them which will allow them
          # to use the password reset link on the login page to generate a new reset.
          sign_out
          redirect_to new_user_session_path
        end
      end
    end

    def password_reset_message
      "If a valid account is found for #{params[:email]}, instructions for resetting the password will be emailed to that address."
    end
end
