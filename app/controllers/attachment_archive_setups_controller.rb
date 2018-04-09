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
    make_params_consistent(params)
    if s.update_attributes(params[:attachment_archive_setup])
      add_flash :notices, "Your setup was successfully updated."
      redirect_to [s.company,s]
    else
      error_redirect "Your setup could not be updated."
    end
  end
  def create
    make_params_consistent(params)
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
  
  def make_params_consistent ps
    unless ps[:attachment_archive_setup][:combine_attachments] == "1"
      ps[:attachment_archive_setup][:combined_attachment_order] = "" 
      ps[:attachment_archive_setup][:include_only_listed_attachments] = "0" 
      ps[:attachment_archive_setup][:send_in_real_time] = "0"
    end
  end

  def secure_me
    if !current_user.admin?
      error_redirect "You do not have permission to access this page."
      return false
    end
    true
  end
end
