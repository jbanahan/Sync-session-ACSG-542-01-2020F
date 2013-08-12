class DutyCalcImportFilesController < ApplicationController
  before_filter :secure_me

  def download
    d = DutyCalcImportFile.find params[:id] 
    if d.attachment.blank?
      error_redirect "Import file does not have an attachment."
    else
      redirect_to download_attachment_path(d.attachment)  
    end
  end

  def create
    importer_id = params[:importer_id]
    zip = nil
    begin
      exp_file, zip = DutyCalcImportFile.delay.generate_for_importer importer_id, current_user
    ensure
      File.delete zip if zip
    end
    add_flash :notices, "File queued for processing. You'll receive a system message when it's done."
    redirect_to drawback_upload_files_path
  end

  private
  def secure_me
    head :forbidden unless current_user.edit_drawback?
  end
end
