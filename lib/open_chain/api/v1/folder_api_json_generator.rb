require 'open_chain/api/v1/api_json_controller_adapter'
require 'open_chain/api/descriptor_based_api_entity_jsonizer'

module OpenChain; module Api; module V1; class FolderApiJsonGenerator
  include OpenChain::Api::V1::ApiJsonControllerAdapter

  def initialize jsonizer: nil
    jsonizer = jsonizer || OpenChain::Api::DescriptorBasedApiEntityJsonizer.new

    super(core_module: CoreModule::FOLDER, jsonizer: jsonizer)
  end

  def obj_to_json_hash folder
    comment_permissions = {}
    folder.comments.each do |c|
      comment_permissions[c.id] = Comment.comment_json_permissions(c, current_user)
    end

    fields = all_requested_model_field_uids(CoreModule::FOLDER, associations: {"attachments" => CoreModule::ATTACHMENT, "comments" => CoreModule::COMMENT, "groups" => CoreModule::GROUP})
    hash = to_entity_hash(folder, fields, user: current_user)
    # UI needs child keys even if it's blank, so add it in (the jsonizer doesn't build these..not sure I want to add this in there either)
    hash[:attachments] = [] if hash[:attachments].nil?
    hash[:comments] = [] if hash[:comments].nil?
    hash[:groups] = [] if hash[:groups].nil?

    hash[:comments].each do |comment|
      comment[:permissions] = comment_permissions[comment['id']]
      comment[:permissions] = {} if comment[:permissions].nil?
    end

    hash[:permissions] = {can_attach: folder.can_attach?(current_user), can_comment: folder.can_comment?(current_user), can_edit: folder.can_edit?(current_user)}

    hash
  end

end; end; end; end;