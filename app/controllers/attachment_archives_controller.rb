class AttachmentArchivesController < ApplicationController
  def create
    errors = []
    r = nil
    begin
      if current_user.edit_attachment_archives?
        c = Company.find params[:company_id]
        archive_setup = c.attachment_archive_setup
        if archive_setup
          if archive_setup.entry_attachments_available?
            r = archive_setup.create_entry_archive! AttachmentArchiveSetup.next_archive_name(c), params[:max_bytes].to_i
          else
            errors << "No files are available to be archived."
          end
        else
          errors << "#{c.name} does not have an archive setup."
        end
      else
        errors << "You do not have permission to create archives."
      end
    rescue
      $!.log_me
      errors << $!.message
    end
    if errors.empty?
      render :json=>r.attachment_list_json
    else
      render :json=>{'errors'=>errors}.to_json
    end
  end

  def show
    errors = []
    archive = nil
    if current_user.edit_attachment_archives?
      c = Company.find_by_id(params[:company_id])
      archive = c.attachment_archives.find_by_id(params[:id]) unless c.nil?
      if archive.nil?
        errors << "Archive not found."
      end
    else
      errors << "You do not have permission to view archives."
    end

    if errors.empty?
      render :json=>archive.attachment_list_json
    else
      render :json=>{'errors'=>errors}.to_json
    end
  end

  def complete
    raise ActionController::RoutingError.new('Not Found') unless current_user.edit_attachment_archives?
    arch = Company.find(params[:company_id]).attachment_archives.find_by_id(params[:id])
    raise ActionController::RoutingError.new('Not Found') unless arch
    arch.update_attributes :finish_at=>Time.now
    render :nothing=>true
  end

  private
end
