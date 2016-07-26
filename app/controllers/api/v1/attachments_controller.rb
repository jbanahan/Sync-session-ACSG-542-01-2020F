require 'open_chain/workflow_processor'

module Api; module V1; class AttachmentsController < Api::V1::ApiController
  include PolymorphicFinders
  include ApiJsonSupport

  # The create call is done via a multipart/form posting..so don't check for json
  skip_before_filter :validate_format, only: [:create]

  def index
    find_object(params, current_user) do |obj|
      attachments = []
      obj.attachments.select {|a| a.can_view? current_user}.each do |a|
        attachments << attachment_view(current_user, a)
      end

      render json: {"attachments" => attachments}
    end
  end

  def show
    find_object(params, current_user) do |obj|
      attachment = obj.attachments.find {|a| a.id == params[:id].to_i }
      if attachment && attachment.can_view?(current_user)
        render json: {"attachment" => attachment_view(current_user, attachment)}
      else
        render_forbidden
      end
    end
  end

  def destroy
    edit_object(params, current_user) do |obj|
      attachment = obj.attachments.find {|a| a.id == params[:id].to_i }
      if attachment
        deleted = false
        Attachment.transaction do
          attachment.destroy
          attachment.rebuild_archive_packet
          deleted = true
        end

        OpenChain::WorkflowProcessor.async_process(obj) if deleted
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

        OpenChain::WorkflowProcessor.async_process(obj)
        obj.log_update(current_user) if obj.respond_to?(:log_update)
        obj.attachment_added(attachment) if obj.respond_to?(:attachment_added)

        render json: {"attachment" => attachment_view(current_user, attachment)}
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
      render json: {"attachment_types" => AttachmentType.all.map {|t| {name: t.name, value: t.name}} }
    end
  end

  private

    def render_download attachment
      expires_in = Time.zone.now + 5.minutes
      if MasterSetup.get.custom_feature?('Attachment Mask')
        url = download_attachment_url attachment, protocol: (Rails.env.production? ? "https" : "http"), host: MasterSetup.get.request_host
      else
        url = attachment.secure_url expires_in
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
        yield obj
      else
        render_forbidden
        nil
      end
    end

    def attachment_view user, attachment
      fields = all_requested_model_field_uids(CoreModule::ATTACHMENT)
      h = to_entity_hash(attachment, fields, user: user)
      h['friendly_size'] = ActionController::Base.helpers.number_to_human_size(attachment.attached_file_size)
      h
    end

end; end; end;
