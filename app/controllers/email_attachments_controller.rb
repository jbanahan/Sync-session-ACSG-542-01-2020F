class EmailAttachmentsController < ApplicationController
  skip_before_filter :require_user
  
  def show
  end

  def download
    ea = EmailAttachment.where(:id => params[:id]).first
    email = params[:email]

    if ea.blank?
      add_flash :errors, "Requested attachment could not be found."
      redirect_to request.referrer
    elsif ea.email.upcase.split(/[,;]/).include?(email.upcase)
      # Technically, the user portion of the email address is allowed to be case-sensitive.
      # In practice this isn't done by any email server/service of note.  
      # We should be fine not worrying about it and upcasing the whole address for our use here.
      send_data ea.attachment.attached,
                :filename => ea.attachment.attached_file_name,
                :type => ea.attachment.attached_content_type,
                :disposition => 'attachment'
    else
      add_flash :errors, "Attachment is not registered for given e-mail address"
      redirect_to email_attachments_show_path
    end
  end
end
