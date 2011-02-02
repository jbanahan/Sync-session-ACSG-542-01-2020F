class AttachmentsController < ApplicationController
  def create
    if att = Attachment.create(params[:attachment])
      attachable = att.attachable
      unless attachable.can_edit?(current_user)
        att.destroy
        add_flash :errors, "You do not have permission to attach items to this object."
      end
      att.uploaded_by = current_user
      att.save
    else
      errors_to_flash att
    end
    
    redirect_to attachable
  end
  
  def destroy
    att = Attachment.find(params[:id])
    attachable = att.attachable
    if attachable.can_edit?(current_user)
      att.destroy
      errors_to_flash att
    else
      add_flash :errors, "You do not have permission to delete this attachment."
    end
    
    redirect_to attachable
  end
end