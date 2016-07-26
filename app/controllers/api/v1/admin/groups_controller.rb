module Api; module V1; module Admin; class GroupsController < Api::V1::GroupsController
  before_filter :require_admin

  def create
    save_group current_user, Group.new
  end

  def update
    group = Group.where(id: params[:id]).first
    if group
      save_group(current_user, group)
    else
      raise ActiveRecord::RecordNotFound
    end
  end

  def destroy
    group = Group.where(id: params[:id]).first
    if group
      group.destroy
      render_ok
    else
      raise ActiveRecord::RecordNotFound
    end
  end

  private
    def save_group user, group
      all_requested_model_fields(CoreModule::GROUP).each {|mf| mf.process_import(group, params[mf.uid], user) unless params[mf.uid].nil? }
      # We block the setting of system code, as we don't allow the field to be updated...so set it manually only on creates
      group.system_code = params["grp_system_code"] if params["grp_system_code"].presence && !group.persisted?

      group.save
      if group.errors.any?
        render_error g.errors
      else
        render json: {"group" => group_view(user, group)}
      end
    end

end; end; end; end