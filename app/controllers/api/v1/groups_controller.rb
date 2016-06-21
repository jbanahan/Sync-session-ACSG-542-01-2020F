module Api; module V1; class GroupsController < Api::V1::ApiController
  include Api::V1::ApiJsonSupport
  include PolymorphicFinders

  def index
    groups = Group.all
    render json: {"groups" => groups.map {|g| group_view(current_user, g)}}
  end

  def show
    group = Group.where(id: params[:id]).first
    if group
      render json: {"group" => group_view(current_user, group)}
    else
      raise ActiveRecord::RecordNotFound
    end
  end

  # Adds the specified group to the given object.
  def add_to_object
    obj = polymorphic_find(params[:base_object_type], params[:base_object_id])
    group = Group.find params[:id]
    if obj && obj.can_edit?(current_user) && obj.respond_to?(:groups)
      obj.groups << group
      render_ok
    else
      render_forbidden
    end
  end

  protected

    def group_view user, group
      fields = all_requested_model_field_uids(CoreModule::GROUP)
      hash = to_entity_hash(group, fields, user: user)
      if include_association? "users"
        hash['users'] = group.users.map {|u| u.api_hash(include_permissions: false)}
      end
      hash
    end

end; end; end