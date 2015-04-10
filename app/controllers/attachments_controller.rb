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
        if att.attached_file_size.nil?
          att.delete
          add_flash :errors, "Please choose a file before uploading."
          respond_to do |format|
            format.html {redirect_to redirect_location(attachable)}
            format.json {render json: Attachment.attachments_as_json(attachable)}
          end
          return nil #avoid frozen hash issues with the rest of the action
        end
        att.uploaded_by = current_user
        att.save
        attachable.log_update(current_user) if attachable.respond_to?(:log_update)
        respond_to do |format|
          format.html {redirect_to redirect_location(attachable)}
          format.json {render json: Attachment.attachments_as_json(attachable)}
        end
      else
        errors_to_flash att
        respond_to do |format|
          format.html {redirect_to redirect_location(attachable)}
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

    redirect_to redirect_location(attachable)
  end

  def download
    att = Attachment.find(params[:id])
    attachable = att.attachable
    if att.can_view?(current_user)
      redirect_to att.secure_url
    else
      error_redirect "You do not have permission to download this attachment."
    end
  end

  def show_email_attachable
    @attachments_array = Attachment.where(attachable_type: params[:attachable_type], attachable_id: params[:attachable_id]).find_all {|a| a.can_view?(current_user)}
    if @attachments_array.size > 0
      @attachable = @attachments_array.first.attachable
    else
      add_flash :errors, "No attachments available to email."
      begin
        attachable = params[:attachable_type].to_s.camelize.constantize.where(id: params[:attachable_id]).first
        redirect_to redirect_location attachable
      rescue
        redirect_back_or_default :root
      end
      return
    end
  end

  def send_email_attachable
    Attachment.delay.email_attachments({to_address: params[:to_address], email_subject: params[:email_subject], email_body: params[:email_body], ids_to_include: params[:ids_to_include], full_name: current_user.full_name, email: current_user.email})
    render text: "OK"
  end

  private
  def redirect_location attachable
    params[:redirect_to].blank? ? attachable : params[:redirect_to]
  end

end
