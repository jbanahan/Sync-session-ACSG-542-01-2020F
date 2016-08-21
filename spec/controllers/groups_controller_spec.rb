require 'spec_helper'

describe GroupsController do
  before(:each) do
        User.scoped.destroy_all #clear default sysadmin user
        @user = Factory(:user, admin: true)
        sign_in_as @user
  end

  describe "create" do
    before(:each) do
      @jim = Factory(:user, username: "Jim")
      @mary = Factory(:user, username: "Mary")
      @rob = Factory(:user, username: "Rob")
      @alice = Factory(:user, username: "Alice")
    end

    context "with valid attributes" do
      it "should save the new group to the db" do
        post :create, group: {name: "admin"}, members_list: "#{@jim.id},#{@mary.id},#{@rob.id}"
        group = Group.first
        
        expect(group).not_to be_nil
        expect(group.name).to eq "admin"
        expect(group.users.sort).to eq [@jim, @mary, @rob].sort
        expect(response).to redirect_to groups_path
        expect(flash[:notice]).to include("Group created")
      end

      it "shouldn't allow use by non-admin" do
        allow(@user).to receive(:admin?).and_return false

        post :create, group: {name: "admin"}
        group = Group.first
        
        expect(group).to be nil
        expect(response).to redirect_to request.referrer
        expect(flash[:errors]).to include("Only a system administrator can perform this action.")
      end
    end

    context "with invalid attributes" do
      it "should prevent group without a name from being saved" do
        post :create, group: {name: ""}
        group = Group.last
        expect(group).to be nil
        expect(response).to redirect_to new_group_path(group)
        expect(flash[:errors][0]).to match(/can't be blank/)
      end

      it "should prevent group with a duplicate system code from being saved" do
        Factory(:group, name: "admin", system_code: "ABCDE")
        post :create, group: {name: "payroll", system_code: "ABCDE"}

        expect(Group.count).to eq 1
        expect(response).to redirect_to new_group_path
        expect(flash[:errors][0]).to match(/has already been taken/)
      end

    end

  end

  describe "update" do
    before(:each) do
      @g = Factory(:group, name: "test_group", description: "group for testing", system_code: "gk2000")
      @jim = Factory(:user, username: "Jim", groups: [@g])
      @mary = Factory(:user, username: "Mary", groups: [@g])
      @rob = Factory(:user, username: "Rob", groups: [@g])
      @alice = Factory(:user, username: "Alice", groups: [@g])

      @burt = Factory(:user, username: "Burt")
      @kate = Factory(:user, username: "Kate")
      @tom = Factory(:user, username: "Tom")
    end

    it "shouldn't allow use by non-admin" do
      allow(@user).to receive(:admin?).and_return false
      put :update, id: @g, members_list: "#{@jim.id}, #{@burt.id}", group: {name: "new name", description: "new description"}
      users = User.all
      members = users.select{ |u| u.groups == [@g] }
      non_members = users.select{ |u| u.groups == [] }
      description = @g.description
      name = @g.name

      #No change for these
      expect(name).to eq "test_group"
      expect(description).to eq "group for testing"
      expect(members.sort).to eq [@jim, @mary, @rob, @alice].sort
      expect(non_members.sort).to eq [@user, @burt, @kate, @tom].sort
      
      expect(response).to redirect_to request.referrer
      expect(flash[:errors]).to include("Only a system administrator can perform this action.")
    end

    it "should assign group membership to some users, unassign it from others, change description" do
      put :update, id: @g, members_list: "#{@jim.id}, #{@kate.id}, #{@rob.id}, #{@burt.id}", group: {name: "new name", description: "new description"}
      @g.reload
      users = User.all
      members = users.select{ |u| u.groups == [@g] }
      non_members = users.select{|u| u.groups == [] }
      members = users.select{ |u| u.groups == [@g] }
      non_members = users.select{ |u| u.groups == [] }
      description = @g.description
      name = @g.name

      expect(name).to eq "new name"
      expect(description).to eq "new description"
      expect(members.sort).to eq [@jim, @rob, @burt, @kate].sort
      expect(non_members.sort).to eq [@user, @mary, @alice, @tom].sort
      expect(response).to redirect_to edit_group_path(@g)
      expect(flash[:notice]).to include("Group updated")
    end

    it "should empty group if no members selected" do
      put :update, id: @g, members_list: "", group: { name: "group for testing" }
      users = User.all
      members = users.select{ |u| u.groups == [@g] }
      non_members = users.select{ |u| u.groups == [] }
      
      expect(members).to be_empty
      expect(non_members.sort).to eq [@user, @jim, @mary, @rob, @alice, @burt, @kate, @tom].sort
      expect(response).to redirect_to edit_group_path(@g)
      expect(flash[:notice]).to include("Group updated")
    end

    it "should prevent update to a blank name" do 
      put :update, id: @g, group: {name: ""}
      expect(@g.name).to eq "test_group"
      expect(response).to redirect_to edit_group_path(@g)
      expect(flash[:errors][0]).to match(/can't be blank/)
    end
  end

  describe "delete" do
    before(:each) { @g = Factory(:group, name: "test_group") }
    
    it "shouldn't allow use by non-admin" do
      allow(@user).to receive(:admin?).and_return false
      delete :destroy, id: @g
      
      expect(Group.count).to eq 1
      expect(response).to redirect_to request.referrer
      expect(flash[:errors]).to include("Only a system administrator can perform this action.") 
    end

    it "should not delete a non-empty group" do
      @user.groups << @g
      @user.save
      delete :destroy, id: @g

      expect(Group.count).to eq 1
      expect(response).to redirect_to edit_group_path(@g)
      expect(flash[:errors]).to include("Only empty groups can be deleted.")
    end

    it "should delete the selected group from the db" do
      delete :destroy, id: @g

      expect(Group.count).to eq 0
      expect(response).to redirect_to groups_path
      expect(flash[:notice]).to include("Group deleted")
    end
  end

  describe "index" do
    before(:each) do
      Factory(:group, name: "A group")
      Factory(:group, name: "B group")
      Factory(:group, name: "C group")
    end

    it "shouldn't allow use by non-admin" do
      allow(@user).to receive(:admin?).and_return false
      get :index

      expect(response).to redirect_to request.referrer
      expect(flash[:errors]).to include ("Only a system administrator can view this page.")
    end

    it "should list groups" do
      groups = Group.order(:name)
      get :index

      expect(assigns(:groups)).to eq groups
      expect(response).to render_template :index 
    end

  end

  describe "edit" do
    before(:each) { @g = Factory(:group, name: "test_group") }

    it "shouldn't allow use by non-admin" do
      allow(@user).to receive(:admin?).and_return false
      get :edit, id: @g

      expect(response).to redirect_to request.referrer
      expect(flash[:errors]).to include ("Only a system administrator can view this page.")
    end

    it "should show edit page for selected group" do
      jim = Factory(:user, username: "Jim", groups: [@g])
      mary = Factory(:user, username: "Mary", groups: [@g])
      rob = Factory(:user, username: "Rob", groups: [@g])
      alice = Factory(:user, username: "Alice", groups: [@g])

      burt = Factory(:user, username: "Burt")
      kate = Factory(:user, username: "Kate")
      tom = Factory(:user, username: "Tom")

      get :edit, id: @g
      expect(assigns(:group)).to eq @g
      expect(assigns(:new_members).sort).to eq [jim, mary, rob, alice].sort
      expect(assigns(:new_non_members).sort).to eq [@user, burt, kate, tom].sort
      expect(response).to render_template :edit
    end
  end

  describe "new" do

    it "shouldn't allow use by non-admin" do
      allow(@user).to receive(:admin?).and_return false
      get :new

      expect(response).to redirect_to request.referrer
      expect(flash[:errors]).to include ("Only a system administrator can view this page.")
    end

    it "should show new page" do
      burt = Factory(:user, username: "Burt")
      kate = Factory(:user, username: "Kate")
      tom = Factory(:user, username: "Tom")

      get :new

      expect(assigns(:group)).to be_instance_of Group
      expect(assigns(:new_members)).to be_empty
      expect(assigns(:new_non_members).sort).to eq [@user, burt, kate, tom].sort
      expect(response).to render_template :new
    end

  end


end