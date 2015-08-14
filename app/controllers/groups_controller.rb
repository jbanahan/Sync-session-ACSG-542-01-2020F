class GroupsController < ApplicationController

  def create
    admin_secure("Only a system administrator can perform this action.") {
      group = Group.new(params[:group])
      if group.save
        
        User.transaction do
          new_members = params[:members_list].blank? ? [] : params[:members_list].split(",").map{|x| User.find(x.to_i)}
          group.users.concat(new_members)
        end

        flash[:notice] = "Group created"
        redirect_to groups_path
        return
      else
        errors_to_flash group, :now => true
        render :new
      end
    }
  end

  def update
    admin_secure("Only a system administrator can perform this action.") {
      group = Group.find(params[:id])
      form_list = params[:members_list].blank? ? [] : params[:members_list].split(",").map{|x| x.to_i}
      group.name = params[:group][:name]
      group.description = params[:group][:description]
      unless group.save
        errors_to_flash group, :now => true
        redirect_to edit_group_path(group)
        return
      end

      Group.transaction do 
        group.users.delete_all
        form_list.each do |uid|
          group.users << User.find(uid)
        end
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
        render :edit
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
      users = User.all
      @new_members, @new_non_members = users.partition{|u| u.groups.include? @group }
    }
  end

  def new
    admin_secure("Only a system administrator can view this page.") {
      @new_non_members = User.all
      @new_members = []
      @group = Group.new
    }
  end

end