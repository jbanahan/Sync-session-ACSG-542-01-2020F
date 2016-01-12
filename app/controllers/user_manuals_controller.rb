class UserManualsController < ApplicationController
  around_filter :admin_secure, except: [:download]
  def index
    @user_manuals = UserManual.order(:name)
  end

  def update
    um = UserManual.find params[:id]
    um.update_attributes(params[:user_manual])
    errors_to_flash um
    redirect_to user_manuals_path
  end

  def create
    begin
      UserManual.transaction do
        return error_redirect "You must attach a file." unless params[:user_manual_file]
        um = UserManual.create(params[:user_manual])
        if um.errors.blank?
          um.create_attachment!(attached:params[:user_manual_file])
        end
        redirect_to user_manuals_path
      end
    rescue
      $!.log_me
      error_redirect $!.message
    end
  end

  def edit
    @user_manual = UserManual.find params[:id]
  end

  def destroy
    UserManual.find(params[:id]).destroy
    add_flash :notices, "User Manual deleted."
    redirect_to user_manuals_path
  end

  def download
    um = UserManual.find params[:id]
    return error_redirect "This Manual does not have an attachment." unless um.attachment
    if um.can_view?(current_user)
      redirect_to um.attachment.secure_url
    else
      admin_secure do
        redirect_to um.attachment.secure_url
      end
    end
  end
end