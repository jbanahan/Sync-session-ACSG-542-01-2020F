class AttachmentArchiveSetupsController < ApplicationController
  before_filter :secure_me
  def show
    flash.keep
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
    params[:attachment_archive_setup][:combined_attachment_order] = "" unless params[:attachment_archive_setup][:combine_attachments] == "1"
    if s.update_attributes(params[:attachment_archive_setup])
      add_flash :notices, "Your setup was successfully updated."
      redirect_to [s.company,s]
    else
      error_redirect "Your setup could not be updated."
    end
  end
  def create
    @aas = AttachmentArchiveSetup.new(params[:attachment_archive_setup])

    c = Company.find params[:company_id]
    if c.attachment_archive_setup
      error_redirect "This company already has an attachment archive setup."
      return
    end

    if @aas.save!
      c.attachment_archive_setup = @aas; c.save!
      add_flash :notices, "Your setup was successfully created."
    else
      errors_to_flash c.create_attachment_archive_setup(params[:attachment_archive_setup])
    end
    
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
