require 'spec_helper'

describe ProjectsController do
  before :each do
    @u = Factory(:master_user,project_view:true,project_edit:true)
    MasterSetup.get.update_attributes(project_enabled:true)

    sign_in_as @u
  end
  describe :index do
    it "should error if user cannot view projects" do
      User.any_instance.stub(:view_projects?).and_return false
      get :index
      expect(response).to be_redirect
      expect(flash[:errors].first).to eq "You do not have permission to view projects."
    end
    it "should pass if user can view projects" do
      p = Factory(:project)
      get :index
      expect(response).to be_success
      expect(assigns(:projects).to_a).to eq [p]
    end
  end
  describe :show do
    it "should error if user cannot view project and request is json" do
      Project.any_instance.stub(:can_view?).and_return false
      p = Factory(:project)
      get :show, 'id'=>p.id.to_s, :format=>:json
      expect(response.status).to eq 401
      expect(JSON.parse(response.body)['error']).to eq "You do not have permission to view this project."
    end
    it "should pass if user can view project" do
      Project.any_instance.stub(:can_view?).and_return true
      p = Factory(:project)
      get :show, 'id'=>p.id.to_s
      expect(response).to be_success
      expect(assigns(:project_id)).to eq p.id.to_s
    end
  end
  describe :update do
    it "should error if user cannot edit project" do
      p = Factory(:project,name:'old')
      Project.any_instance.stub(:can_edit?).and_return false
      put :update, 'id'=>p.id.to_s, 'project'=>{'id'=>p.id,:name=>'my name'}
      expect(response.status).to eq 401
      expect(JSON.parse(response.body)['error']).to eq "You do not have permission to edit this project."
      p.reload
      expect(p.name).to eq 'old'
    end
    it "should return json of updated project" do
      p = Factory(:project,name:'old')
      Project.any_instance.stub(:can_edit?).and_return true
      put :update, 'id'=>p.id.to_s, 'project'=>{'id'=>p.id,:name=>'my name'}
      p.reload
      expect(p.name).to eq 'my name'
      expect(response).to be_success
      expect(JSON.parse(response.body)['project']['name']).to eq 'my name'
    end
  end
  describe :create do
    it "should error if user cannot edit projects" do
      User.any_instance.stub(:edit_projects?).and_return false
      post :create, 'project'=>{'name'=>'my name'}
      expect(Project.all).to be_empty
      expect(response).to be_redirect
      expect(flash[:errors].first).to match /permission/
    end
    it "should create project and redirect" do
      User.any_instance.stub(:edit_projects?).and_return true
      post :create, 'project'=>{'name'=>'my name'}
      p = Project.first
      expect(p.name).to eq 'my name'
      expect(response).to redirect_to p
    end
  end
  describe :toggle_close do
    before :each do
      @p = Factory(:project)
    end
    it "should close open project" do
      User.any_instance.stub(:edit_projects?).and_return true
      put :toggle_close, :id=>@p.id
      expect(response).to be_success
      @p.reload
      expect(@p.closed_at).to be > 2.seconds.ago
      expect(JSON.parse(response.body)['project']['closed_at']).not_to be_blank
    end
    it "should open closed project" do
      @p.update_attributes(closed_at:1.day.ago)
      User.any_instance.stub(:edit_projects?).and_return true
      put :toggle_close, :id=>@p.id
      expect(response).to be_success
      @p.reload
      expect(@p.closed_at).to be_nil
      expect(JSON.parse(response.body)['project']['closed_at']).to be_blank
    end
    it "should reject on can't edit" do
      User.any_instance.stub(:edit_projects?).and_return false
      put :toggle_close, :id=>@p.id
      expect(response.status).to eq 401
      expect(JSON.parse(response.body)['error']).to match /permission/
      @p.reload
      expect(@p.closed_at).to be_nil
    end
  end
  describe :toggle_on_hold do
    before :each do
      @p = Factory(:project)
    end
    it "should put a hold on a going project" do
      User.any_instance.stub(:edit_projects?).and_return true
      put :toggle_on_hold, id: @p.id
      expect(response).to be_success
      @p.reload
      @p.on_hold.should be_true
      expect(JSON.parse(response.body)['project']['on_hold']).to eq(true)
    end
    it "should lift a hold on a held project" do
      @p.update_attributes(on_hold: true)
      User.any_instance.stub(:edit_projects?).and_return true
      put :toggle_on_hold, id: @p.id
      expect(response).to be_success
      @p.reload
      @p.on_hold.should be_false
      expect(JSON.parse(response.body)['project']['on_hold']).to eq(false)
    end
    it "should reject if you can't edit" do
      User.any_instance.stub(:edit_projects?).and_return false
      put :toggle_on_hold, id: @p.id
      expect(response.status).to eq(401)
      expect(JSON.parse(response.body)['error']).to match /permission/
      @p.reload
      expect(@p.on_hold).to be_nil
    end
    it "should reject if the project is closed" do
      @p.update_attributes(closed_at: Time.now - 5.minutes)
      User.any_instance.stub(:edit_projects?).and_return true
      put :toggle_on_hold, id: @p.id
      expect(response.status).to eq(401)
      expect(JSON.parse(response.body)['error']).to match /Closed projects can not be put on hold/
      @p.reload
      expect(@p.on_hold).to_not be_true
    end
  end
  describe :add_project_set do
    before :each do
      @p = Factory(:project)
    end
    it "should allow adding existing project set" do
      ps = Factory(:project_set)
      User.any_instance.stub(:edit_projects?).and_return true
      post :add_project_set, :id=>@p.id, :project_set_name=>ps.name
      expect(response).to be_success
      @p.reload
      expect(@p.project_sets.count).to eq 1
      expect(@p.project_sets.first).to eq ps
    end
    it "should allow adding new project set" do
      User.any_instance.stub(:edit_projects?).and_return true
      post :add_project_set, :id=>@p.id, :project_set_name=>'new set'
      expect(response).to be_success
      @p.reload
      expect(@p.project_sets.count).to eq 1
      expect(@p.project_sets.first.name).to eq 'new set'
    end
    it "should fail on empty project_set_name" do
      User.any_instance.stub(:edit_projects?).and_return true
      post :add_project_set, :id=>@p.id, :project_set_name=>' '
      expect(response.status).to eq 400
      expect(JSON.parse(response.body)['error']).to match /blank/
      @p.reload
      expect(@p.project_sets).to be_empty
    end
    it "should reject on can't edit" do
      User.any_instance.stub(:edit_projects?).and_return false
      post :add_project_set, :id=>@p.id, :project_set_name=>'new set'
      expect(response.status).to eq 401
      @p.reload
      expect(@p.project_sets).to be_empty
    end
  end
  describe :remove_project_set do
    before :each do
      @p = Factory(:project)
      @ps = Factory(:project_set)
      @p.project_sets << @ps
      User.any_instance.stub(:edit_projects?).and_return true 
    end
    it "should allow deleting project set" do
      delete :remove_project_set, id: @p.id, project_set_name: @ps.name
      expect(response).to be_success
      @p.reload
      expect(@p.project_sets).to be_empty
    end
    it "should not fail if project set does not exist" do
      delete :remove_project_set, id: @p.id, project_set_name: 'some other name'
      expect(response).to be_success
      @p.reload
      expect(@p.project_sets.to_a).to eq [@ps]
    end
    it "should not fail if project set is not already added" do
      Factory(:project_set, name: 'some other name')
      delete :remove_project_set, id: @p.id, project_set_name: 'some other name'
      expect(response).to be_success
      @p.reload
      expect(@p.project_sets.to_a).to eq [@ps]
    end
    it "should delete project set if it isn't used by any projects" do
      delete :remove_project_set, id: @p.id, project_set_name: @ps.name
      expect(response).to be_success
      expect(ProjectSet.all).to be_empty
    end
    it "should not delete set if still linked to project" do
      p2 = Factory(:project)
      p2.project_sets << @ps
      delete :remove_project_set, id: @p.id, project_set_name: @ps.name
      expect(response).to be_success
      expect(ProjectSet.first).to eq @ps
    end
    it "should fail on empty project set name" do
      delete :remove_project_set, id: @p.id, project_set_name: ''
      expect(response.status).to eq 400
      expect(JSON.parse(response.body)['error']).to match /blank/
    end
    it "should fail on can't edit" do
      User.any_instance.stub(:edit_projects?).and_return false
      delete :remove_project_set, id: @p.id, project_set_name: @ps.name
      expect(response.status).to eq 401
      expect(@p.project_sets.to_a).to eq [@ps]
    end
  end
end
