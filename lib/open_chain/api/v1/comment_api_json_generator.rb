require 'open_chain/api/v1/api_json_controller_adapter'

module OpenChain; module Api; module V1; class CommentApiJsonGenerator
  include OpenChain::Api::V1::ApiJsonControllerAdapter

  def initialize jsonizer: nil
    super(core_module: CoreModule::COMMENT, jsonizer: jsonizer)
  end

  def obj_to_json_hash comment
    fields = all_requested_model_field_uids(CoreModule::COMMENT)
    hash = to_entity_hash(comment, fields)
    if include_association?(:permissions)
      hash['permissions'] = render_permissions(comment, current_user)
    end

    hash
  end

  def render_permissions c, user
    {
      can_view:c.can_view?(user),
      can_edit:c.can_edit?(user),
      can_delete:c.can_delete?(user)
    }
  end

end; end; end; end;