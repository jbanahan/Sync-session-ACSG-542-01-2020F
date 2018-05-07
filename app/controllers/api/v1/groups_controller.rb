require 'open_chain/api/v1/api_json_support'
require 'open_chain/api/v1/group_api_json_generator.rb'

module Api; module V1; class GroupsController < Api::V1::ApiCoreModuleControllerBase
  include PolymorphicFinders

  def index
    groups = Group.all
    render json: {"groups" => groups.map {|g| obj_to_json_hash(g)}}
  end

  def show
    group = Group.where(id: params[:id]).first
    if group
      render json: {"group" => obj_to_json_hash(group)}
    else
      raise ActiveRecord::RecordNotFound
    end
  end

  def show_excluded_users
    group = Group.where(id: params[:id]).first
    render json: {"excluded_users" => excluded_user_view(group)}
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

      render json: {"groups" => groups.map {|g| obj_to_json_hash(g)}}
    end
  end

  def json_generator
    OpenChain::Api::V1::GroupApiJsonGenerator.new
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

    def excluded_user_view group
      hash = {}
      if group
        hash['excl_users'] = User.joins("LEFT OUTER JOIN user_group_memberships m on users.id = m.user_id and m.group_id = #{group.id}")
                                 .where("m.id IS NULL")
                                 .non_system_user
                                 .enabled
                                 .map{ |u| u.api_hash(include_permissions: false)}
      else
        hash['excl_users'] = User.where(system_user: [false, nil]).enabled.map{ |u| u.api_hash(include_permissions: false)}
      end
      json_generator.add_companies(hash['excl_users'])
    end

end; end; end