require 'open_chain/email_validation_support'

class AttachmentsController < ApplicationController
  include DownloadS3ObjectSupport
  include PolymorphicFinders
  include OpenChain::EmailValidationSupport

  skip_before_filter :portal_redirect, only: [:download]

  def create
    if params[:attachment][:attached].nil?
      add_flash :errors, "Please choose a file before uploading."
      respond_to do |format|
        format.html {redirect_to request.referrer}
        format.json {render json: {errors:flash[:errors]}, status: 400}
      end
    else
      att = Attachment.new(params[:attachment])
      attachable = att.attachable
      saved = false
      if attachable.can_attach?(current_user)
        att.uploaded_by = current_user
        if att.save!
          saved = true
          attachable.log_update(current_user) if attachable.respond_to?(:log_update)
          attachable.attachment_added(att) if attachable.respond_to?(:attachment_added)
          attachable.create_async_snapshot current_user, nil, "Attachment Added: #{att.attached_file_name}" if attachable.respond_to?(:create_async_snapshot)
        else
          errors_to_flash att
        end
      else
        add_flash :errors, "You do not have permission to attach items to this object."
      end

      if saved
        respond_to do |format|
          format.html {redirect_to redirect_location(attachable)}
          format.json {render json: Attachment.attachments_as_json(attachable)}
        end
      else
        respond_to do |format|
          format.html {redirect_to redirect_location(attachable)}
          format.json {render json: {errors:flash[:errors]}, status: 400}
        end
      end
    end
  end

  def destroy
    att = Attachment.find(params[:id])
    attachable = att.attachable
    if attachable.can_attach?(current_user)
      deleted = false
      Attachment.transaction do
        deleted = att.destroy
        att.rebuild_archive_packet if deleted
      end
      errors_to_flash att
    else
      add_flash :errors, "You do not have permission to delete this attachment."
    end

    redirect_to redirect_location(attachable)
  end

  def download
    att = Attachment.find(params[:id])
    if att.can_view?(current_user)
      disposition = params[:disposition].to_s
      downcase_disp = disposition.downcase
      if downcase_disp.starts_with?("attachment") || downcase_disp.starts_with?("inline")
        # This is done because the browser guesses at the filename to use if you don't explicitly tell
        # it what to use.  Part of that guessing includes the content-type from S3, which we aren't always
        # setting.  So, the easiest resolution is to just auto add the filename parameter to Content-Disposition
        # if it's not already present.
        if !downcase_disp.include? "filename"
          disposition += "; filename=\"#{att.attached_file_name}\""
        end

        download_attachment att, disposition: disposition
      else
        download_attachment att
      end

    else
      error_redirect "You do not have permission to download this attachment."
    end
  end

  def download_last_integration_file
    downloaded = false
    if current_user.admin? && params[:attachable_type].presence && params[:attachable_id].presence
      begin
        obj = get_attachable params[:attachable_type], params[:attachable_id]
        if obj.respond_to?(:last_file_secure_url) && obj.can_view?(current_user)
          url = obj.last_file_secure_url
          if url
            redirect_to url
            downloaded = true
          end
        end
      rescue
        #don't care...user will redirect to error below if this happens
      end
    end

    if !downloaded
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
        attachable = get_attachable params[:attachable_type], params[:attachable_id]
        redirect_to redirect_location attachable
      rescue
        redirect_back_or_default :root
      end
      return
    end
  end

  def send_email_attachable
    email_list = params[:to_address].split(',')
    if email_list.empty?
      render_json_error "Please enter an email address."
    elsif email_list.count > 10
      render_json_error "Cannot accept more than 10 email addresses."
    elsif !email_list_valid? email_list
      render_json_error "Please ensure all email addresses are valid."
    else
      total_size = Attachment.where("id IN (#{params[:ids_to_include].join(', ')})").sum(:attached_file_size)
      if total_size > 10485760
        render_json_error "Attachments cannot be over 10 MB."
      else
        Attachment.delay.email_attachments({to_address: params[:to_address], email_subject: params[:email_subject], email_body: params[:email_body], ids_to_include: params[:ids_to_include], full_name: current_user.full_name, email: current_user.email})
        render json: {ok: 'OK'}
      end
    end
  end

  private
  def redirect_location attachable
    params[:redirect_to].blank? ? attachable : params[:redirect_to]
  end

  def get_attachable type, id
    attachable = polymorphic_scope(type).where(id: id).first
  end

end
