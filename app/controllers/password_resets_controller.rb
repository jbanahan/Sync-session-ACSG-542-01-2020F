class PasswordResetsController < ApplicationController
  before_filter :ensure_logged_out
  before_filter :load_user_using_perishable_token, :only => [:edit, :update]
  skip_before_filter :require_user
  
  def new
  end

  def create
    @user = User.find_by_email(params[:email])
    if @user
      ActionMailer::Base.default_url_options[:host] = request.host_with_port
      @user.deliver_password_reset_instructions!
      add_flash :notices, "Instructions for resetting your password have been sent to your email."
    else
      add_flash :errors, "No user was found with email \"#{params[:email]}\"."
    end
    redirect_to new_user_session_path
  end


  def edit
  end

  def update
    @user.password = params[:user][:password]
    @user.password_confirmation = params[:user][:password_confirmation]
    if @user.save
      flash[:notice] = "Password successfully updated"
      redirect_to root_url
    else
      render :action => :edit
    end
  end

  private
  def load_user_using_perishable_token
    @user = User.find_using_perishable_token(params[:id])
    unless @user
      add_flash :errors, "We're sorry, but we could not locate your account."
      redirect_to new_user_session_path
    end
  end
  def ensure_logged_out
    u = UserSession.find
    u.destroy if u
  end
end
