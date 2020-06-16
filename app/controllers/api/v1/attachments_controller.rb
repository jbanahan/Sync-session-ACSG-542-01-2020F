require 'open_chain/api/v1/attachment_api_json_generator'

module Api; module V1; class AttachmentsController < Api::V1::ApiCoreModuleControllerBase
  include PolymorphicFinders
  include DownloadS3ObjectSupport

  # The create call is done via a multipart/form posting..so don't check for json
  skip_before_filter :validate_format, only: [:create]

  def index
    find_object(params, current_user) do |obj|
      attachments = []
      obj.attachments.select {|a| a.can_view? current_user}.each do |a|
        attachments << obj_to_json_hash(a)
      end

      render json: {"attachments" => attachments}
    end
  end

  def show
    find_object(params, current_user) do |obj|
      attachment = obj.attachments.find {|a| a.id == params[:id].to_i }
      if attachment && attachment.can_view?(current_user)
        render json: {"attachment" => obj_to_json_hash(attachment)}
      else
        render_forbidden
      end
    end
  end

  def destroy
    edit_object(params, current_user) do |obj|
      attachment = obj.attachments.find {|a| a.id == params[:id].to_i }
      if attachment
        # Once the attachment is destroyed the filename is cleared (this is a paperclip thing)
        filename = attachment.attached_file_name
        deleted = attachment.destroy
        if deleted
          obj.create_async_snapshot current_user, nil, "Attachment Removed: #{filename}" if obj.respond_to?(:create_async_snapshot)
        end

        render_ok
      else
        render_forbidden
      end
    end
  end

  def create
    if params[:file].nil?
      render_error "Missing file data."
    else
      edit_object(params, current_user) do |obj|
        # Every model field for attachment is read-only, so only pull the attachment type from the params and don't use the model field import - since it'll fail due
        # to the model field being read-only.
        attachment = obj.attachments.build attachment_type: params[:att_attachment_type]
        attachment.attached = params[:file]
        attachment.uploaded_by = current_user
        attachment.save!

        obj.log_update(current_user) if obj.respond_to?(:log_update)
        obj.attachment_added(attachment) if obj.respond_to?(:attachment_added)
        obj.create_async_snapshot current_user, nil, "Attachment Added: #{attachment.attached_file_name}" if obj.respond_to?(:create_async_snapshot)

        render json: {"attachment" => obj_to_json_hash(attachment)}
      end
    end
  end

  def download
    find_object(params, current_user) do |obj|
      attachment = obj.attachments.find {|a| a.id == params[:id].to_i }
      if attachment && attachment.can_view?(current_user)
        render_download attachment
      else
        render_forbidden
      end
    end
  end

  def attachment_types
    # At the moment, there is no distinction for attachment types based on the object type in use,
    # however, I'm pretty sure that is coming, so I'm codifying it now.
    find_object(params, current_user) do |obj|
      render json: {"attachment_types" => AttachmentType.by_name.all.map {|t| {name: t.name, value: t.name}} }
    end
  end

  def json_generator
    OpenChain::Api::V1::AttachmentApiJsonGenerator.new
  end

  private

    def render_download attachment
      expires_in = Time.zone.now + 5.minutes
      if MasterSetup.get.custom_feature?('Attachment Mask')
        url = download_attachment_url attachment, protocol: (Rails.env.production? ? "https" : "http"), host: MasterSetup.get.request_host
      else
        url = attachment_secure_url(attachment, expires_in: expires_in)
      end

      render json: {url: url, name: attachment.attached_file_name, expires_at: expires_in.iso8601}
    end

    def find_object params, user
      obj = polymorphic_find(params[:base_object_type], params[:base_object_id])
      if obj && obj.can_view?(user)
        yield obj
      else
        render_forbidden
        nil
      end
    end

    def edit_object params, user
      obj = polymorphic_find(params[:base_object_type], params[:base_object_id])
      if obj && obj.can_attach?(user)
        Lock.db_lock(obj) do
          yield obj
        end
      else
        render_forbidden
        nil
      end
    end

end; end; end;
