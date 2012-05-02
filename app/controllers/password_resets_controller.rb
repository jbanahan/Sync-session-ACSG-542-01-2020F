class PasswordResetsController < ApplicationController
  before_filter :ensure_logged_out, :except => [:forced]
  before_filter :load_user_using_perishable_token, :only => [:edit, :update]
  skip_before_filter :require_user
  skip_before_filter :force_reset, :only => [:update, :forced]
  
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
      @user.update_attributes(:password_reset => false)
      flash[:notice] = "Password successfully updated"
      redirect_to root_url
    else
      render :action => :edit
    end
  end

  def forced
    @no_buttons = true
    @user = current_user
    respond_to do |format|
      format.html { render :edit }
    end
  end

  private
  def load_user_using_perishable_token
    unless @user
      @user = User.find_using_perishable_token(params[:id])
      @user = User.find_by_id(params[:id]) unless @user
      unless @user
        add_flash :errors, "We're sorry, but we could not locate your account."
        redirect_to new_user_session_path
      end
    end
  end
  def ensure_logged_out
    u = UserSession.find
    u.destroy if u
  end
end
