class GroupsController < ApplicationController

  def create
    admin_secure("Only a system administrator can perform this action.") {
      group = Group.new(params[:group])
      if group.save
        
        User.transaction do
          new_members = User.where(id: params[:members_list].split(","))
          group.users.concat(new_members)
        end

        flash[:notice] = "Group created"
        redirect_to groups_path
        return
      else
        errors_to_flash group, :now => true
        redirect_to new_group_path(group)
      end
    }
  end

  def update
    admin_secure("Only a system administrator can perform this action.") {
      group = Group.find(params[:id])
      group.name = params[:group][:name]
      group.description = params[:group][:description]
      unless group.save
        errors_to_flash group, :now => true
        redirect_to edit_group_path(group)
        return
      end

      Group.transaction do 
        new_members = User.where(id: params[:members_list].split(","))
        group.users.delete_all
        group.users.concat(new_members)
      end

      add_flash :notice, "Group updated"
      redirect_to edit_group_path(group)
    }
  end

  def destroy
    admin_secure("Only a system administrator can perform this action.") {
      group = Group.find params[:id]
      unless group.users.empty?
        add_flash :errors, "Only empty groups can be deleted."
        redirect_to edit_group_path(group)
        return
      end
      group.destroy
      add_flash :notice, "Group deleted"
      redirect_to groups_path
    }
  end

  def index
    admin_secure("Only a system administrator can view this page.") {
      @groups = Group.order(:name)
    }
  end

  def edit
    admin_secure("Only a system administrator can view this page.") {
      @group = Group.find(params[:id])
      @new_members = User.enabled.joins("INNER JOIN user_group_memberships m on users.id = m.user_id and m.group_id = #{@group.id}").all
      @new_non_members = User.enabled.joins("LEFT OUTER JOIN user_group_memberships m on users.id = m.user_id and m.group_id = #{@group.id}").where("m.id IS NULL").all
    }
  end

  def new
    admin_secure("Only a system administrator can view this page.") {
      @new_non_members = User.enabled
      @new_members = []
      @group = Group.new
    }
  end

end