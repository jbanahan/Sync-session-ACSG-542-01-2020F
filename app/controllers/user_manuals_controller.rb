class UserManualsController < ApplicationController
  include DownloadS3ObjectSupport

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
      download_attachment um.attachment
    else
      admin_secure do
        download_attachment um.attachment
      end
    end
  end

  def send_manual um
    if MasterSetup.get.custom_feature?('Attachment Mask')
      data = open(um.attachment.secure_url)
      send_data data.read, stream: true,
        buffer_size: 4096, filename: att.attached_file_name,
        disposition: 'attachment', type: att.attached_content_type
    else
      redirect_to um.attachment.secure_url
    end
  end
  private :send_manual
end
