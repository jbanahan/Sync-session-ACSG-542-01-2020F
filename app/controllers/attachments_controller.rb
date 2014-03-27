class AttachmentsController < ApplicationController
  def create
    att = nil
    begin
      if att = Attachment.create(params[:attachment])
        attachable = att.attachable
        unless attachable.can_attach?(current_user)
          att.destroy
          add_flash :errors, "You do not have permission to attach items to this object."
        end
        if att.attached_file_name.nil? and att.attached_file_size.nil?
          att.delete
          add_flash :errors, "Please choose a file before uploading."
          respond_to do |format|
            format.html {redirect_to attachable}
            format.json {render json: Attachment.attachments_as_json(attachable)}
          end
          return nil #avoid frozen hash issues with the rest of the action
        end
        att.uploaded_by = current_user
        att.save
        attachable.log_update(current_user) if attachable.respond_to?(:log_update)
        respond_to do |format|
          format.html {redirect_to attachable}
          format.json {render json: Attachment.attachments_as_json(attachable)}
        end
      else
        errors_to_flash att
        respond_to do |format|
          format.html {redirect_to attachable}
          format.json {render json: {errors:flash[:errors]}, status: 400}
        end
      end
    rescue
      att.destroy unless att.blank?
      raise $!
    end
  end
  
  def destroy
    att = Attachment.find(params[:id])
    attachable = att.attachable
    if attachable.can_attach?(current_user)
      att.destroy
      errors_to_flash att
    else
      add_flash :errors, "You do not have permission to delete this attachment."
    end
    
    redirect_to attachable
  end
  
  def download
    att = Attachment.find(params[:id])
    attachable = att.attachable
    if attachable.can_view?(current_user)
      redirect_to att.secure_url
    else
      error_redirect "You do not have permission to download this attachment."
    end
  end
end
