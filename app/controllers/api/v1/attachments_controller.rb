require 'open_chain/workflow_processor'

module Api; module V1; class AttachmentsController < Api::V1::ApiController

  # The create call is done via a multipart/form posting..so don't check for json
  skip_before_filter :validate_format, only: [:create]

  def show
    att = Attachment.where(attachable_id: params[:attachable_id], attachable_type: get_attachable_type(params[:attachable_type]), id: params[:id]).first

    if att && att.can_view?(current_user)
      render json: Attachment.attachment_json(att)
    else
      raise ActiveRecord::RecordNotFound
    end
  end

  def index 
    att = Attachment.where(attachable_id: params[:attachable_id], attachable_type: get_attachable_type(params[:attachable_type]))

    attachments = []
    att.each do |a|
      if a.can_view? current_user
        attachments << Attachment.attachment_json(a)
      end
    end

    render json: attachments
  end

  def destroy
    attachment = Attachment.where(attachable_id: params[:attachable_id], attachable_type: get_attachable_type(params[:attachable_type]), id: params[:id]).first

    if attachment && attachment.attachable.can_attach?(current_user)
      attachment.destroy
      OpenChain::WorkflowProcessor.async_process(attachment.attachable)
      render json: {}
    else
      raise ActiveRecord::RecordNotFound
    end
  end

  def download
    a = Attachment.where(attachable_id: params[:attachable_id], attachable_type: get_attachable_type(params[:attachable_type]), id: params[:id]).first
    if a.can_view? current_user
      expires_in = Time.zone.now + 5.minutes
      url = a.secure_url expires_in

      render json: {url: url, name: a.attached_file_name, expires_at: expires_in.iso8601}
    else
      raise ActiveRecord::RecordNotFound
    end
  end

  def create
    attachment = Attachment.new attachable_id: params[:attachable_id], attachable_type: get_attachable_type(params[:attachable_type]), attachment_type: params[:type]
    attachable = attachment.attachable
    if params[:file].nil?
      render_error "Missing file data."
    elsif attachable && attachable.can_attach?(current_user)
      attachment.attached = params[:file]
      attachment.uploaded_by = current_user
      attachment.save!

      OpenChain::WorkflowProcessor.async_process(attachable)
      attachable.log_update(current_user) if attachable.respond_to?(:log_update)
      render json: Attachment.attachment_json(attachment)
    else
      raise ActiveRecord::RecordNotFound
    end
  end

  private 
    def get_attachable_type type
      # If there's irregular forms of the attachable_type...add translations here
      # We accept two things here..
      # 1) Send the actual straight up attachable_type as it would appear in the Attachment's attachable_type attribute
      # 2) Send the snake_case pluralized form that would be used in a standard rails route.
      # In general though, it's going to take 'snake_cases' and turn it into 'SnakeCase' and then verify the value
      # can be constantized and is an ActiveModel class

      # first, just attempt to constantize the type name straight off, since we do allow sending the type directly, .ie "Entry" vs. "entries"
      camelized_type = type.to_s.camelize
      attachable_type = validate_attachable_class_name(type.camelize)
      if attachable_type.nil?
        attachable_type = validate_attachable_class_name(camelized_type.singularize)
      end

      raise StatusableError.new("Invalid attachable_type.", :internal_server_error) if attachable_type.nil?

      attachable_type
    end

    def validate_attachable_class_name class_name
      begin
        klass = class_name.constantize
        # If < is true, it means class inherits from ActiveRecord::Base
        return klass < ActiveRecord::Base ? klass.name : nil
      rescue NameError
        nil
      end
    end

end; end; end;