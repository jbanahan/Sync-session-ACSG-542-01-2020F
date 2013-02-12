class AttachmentArchiveManifestsController < ApplicationController 
  before_filter :secure
  def create
    m = Company.find(params[:company_id]).attachment_archive_manifests.create!
    m.delay.make_manifest!
    render :json => {'id'=>m.id}.to_json
  end

  def download
    m = Company.find(params[:company_id]).attachment_archive_manifests.find(params[:id])
    if m.attachment && m.attachment.attached && m.attachment.attached.exists?
      redirect_to m.attachment.secure_url
    else
      render :nothing=>true, :status=>204
    end
  end

  private 
  def secure
    if current_user.view_attachment_archives?
      return true
    else
      error_redirect "You do not have permission to work with archive manifests."
      return false
    end
  end
end
