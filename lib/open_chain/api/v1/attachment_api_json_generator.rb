require 'open_chain/api/v1/api_json_controller_adapter'

module OpenChain; module Api; module V1; class AttachmentApiJsonGenerator
  include OpenChain::Api::V1::ApiJsonControllerAdapter

  def initialize jsonizer: nil
    super(core_module: CoreModule::ATTACHMENT, jsonizer: jsonizer)
  end

  #needed for index
  def obj_to_json_hash attachment
    fields = all_requested_model_field_uids(CoreModule::ATTACHMENT)
    h = to_entity_hash(attachment, fields, user: current_user)
    h['friendly_size'] = ActionController::Base.helpers.number_to_human_size(attachment.attached_file_size)
    h
  end

end; end; end; end;