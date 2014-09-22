class PasswordResetsController < ApplicationController
  before_filter :load_user_using_perishable_token, :only => [:edit, :update]
  skip_before_filter :require_user
  skip_before_filter :force_reset

  def create
    @user = User.find_by_email(params[:email])
    if @user
      if @user.disallow_password?
        add_flash :errors, "You do not have a password enabled login"
      else
        @user.delay.deliver_password_reset_instructions!
        add_flash :notices, "Instructions for resetting your password have been emailed to you."
      end
    else
      add_flash :errors, "No user was found with email \"#{params[:email]}\"."
    end
    redirect_to new_user_session_path
  end


  def edit
  end

  def update
    success = false
    if @user.update_user_password params[:user][:password], params[:user][:password_confirmation]
      @user.update_attributes(:password_reset => false)
      # Have to actually sign in the user here via clearance to set their remember token
      sign_in(@user) do |status|
        success = status.success?
      end
    end

    if success
      @user.on_successful_login request
      flash[:notice] = "Password successfully updated"
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
end
