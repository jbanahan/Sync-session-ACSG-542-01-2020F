class UserManualsController < ApplicationController
  include DownloadS3ObjectSupport
  include UserManualHelper

  skip_before_filter :portal_redirect, only: [:download]
  around_filter :admin_secure, except: [:download,:for_referer]
  def set_page_title
    @page_title = 'Tools'
  end
  def index
    @user_manuals = UserManual.all
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
        um = UserManual.create(params[:user_manual])
        if um.errors.blank? && params[:user_manual_file]
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

  def for_referer
    ref = request.referer
    ref = '' if request.referer.blank?
    @manuals = UserManual.for_user_and_page(current_user,ref).sort {|a,b| a.name.downcase <=> b.name.downcase}
    render layout: false
  end

end
