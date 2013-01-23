class AttachmentArchiveSetupsController < ApplicationController
  before_filter :secure_me
  def show
    redirect_to edit_company_attachment_archive_setup_path(params[:company_id],params[:id])
  end
  def new
    @company = Company.find params[:company_id]
    @company.build_attachment_archive_setup
  end
  def edit
    @company = AttachmentArchiveSetup.find(params[:id]).company
  end
  def update
    s = AttachmentArchiveSetup.find(params[:id])
    s.update_attributes(params[:attachment_archive_setup])
    redirect_to [s.company,s]
  end
  def create
    c = Company.find params[:company_id]
    if c.attachment_archive_setup
      error_redirect "This company already has an attachment archive setup."
      return
    end
    errors_to_flash c.create_attachment_archive_setup(params[:attachment_archive_setup])
    redirect_to [c,c.attachment_archive_setup]
  end



  private
  def secure_me
    if !current_user.admin?
      error_redirect "You do not have permission to access this page."
      return false
    end
    true
  end
end
