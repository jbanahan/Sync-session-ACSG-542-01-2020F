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
    edit_object(current_user, params) do |obj|
      group = Group.find params[:id]
      if group
        obj.groups << group
        render_ok
      else
        render_forbidden
      end
    end
  end

  def set_groups_for_object
    edit_object(current_user, params) do |obj|
      groups = Group.where(id: Array.wrap(params[:groups]).map {|g| g[:id]}).all
      Group.transaction do
        # Remove all the groups from the object and recreate them from the ones sent in the request
        obj.groups.destroy_all
        obj.groups << groups
      end

      render json: {"groups" => groups.map {|g| group_view(current_user, g)}}
    end
  end

  protected

    def edit_object(user, params)
      obj = polymorphic_find(params[:base_object_type], params[:base_object_id])
      if obj && obj.can_edit?(user) && obj.respond_to?(:groups)
        yield obj
      else
        render_forbidden
      end
    end

    def group_view user, group
      fields = all_requested_model_field_uids(CoreModule::GROUP)
      hash = to_entity_hash(group, fields, user: user)
      if include_association? "users"
        hash['users'] = group.users.map {|u| u.api_hash(include_permissions: false)}
      end
      hash
    end

end; end; end