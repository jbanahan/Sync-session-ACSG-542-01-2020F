require 'spec_helper'

describe ProjectDeliverablesController do
  before :each do
    @u = Factory(:master_user,project_view:true,project_edit:true)
    MasterSetup.get.update_attributes(project_enabled:true)
    activate_authlogic
    UserSession.create! @u
  end
  describe :index do
    before :each do
      @u1 = Factory(:user)
      @u2 = Factory(:user)
      @d1 = Factory(:project_deliverable,assigned_to_id:@u1.id,project:Factory(:project,name:'pn1'))
      @d2 = Factory(:project_deliverable,assigned_to_id:@u2.id,project:Factory(:project,name:'pn2'))
      @d3 = Factory(:project_deliverable,complete:true)
    end
    it "should return all incomplete" do
      get :index, format: :json
      expect(response).to be_success
      r = JSON.parse(response.body)['deliverables_by_user']
      expect(r[@u1.full_name]['pn1'][0]['id']).to eq @d1.id
      expect(r[@u2.full_name]['pn2'][0]['id']).to eq @d2.id
    end
    it "should not return for closed projects" do
      @d1.project.update_attributes(closed_at:Time.now)
      get :index, format: :json
      expect(response).to be_success
      r = JSON.parse(response.body)['deliverables_by_user']
      expect(r.size).to eq 1
      expect(r[@u2.full_name]['pn2'][0]['id']).to eq @d2.id
    end
    it "should sort by project" do
      get :index, format: :json, layout: 'project'
      r = JSON.parse(response.body)['deliverables_by_user']
      expect(r['pn1'][@u1.full_name][0]['id']).to eq @d1.id
    end
    it "should error if user cannot view projects" do
      User.any_instance.stub(:view_projects?).and_return false
      get :index, format: :json
      expect(JSON.parse(response.body)['error']).to match /permission/
      expect(response.status).to eq 401
    end
    it "should duplicate deliverables by project set" do
      ps1 = ProjectSet.create!(name:'myps')
      ps2 = ProjectSet.create!(name:'myps2')
      @d1.project.project_sets << ps1
      @d1.project.project_sets << ps2
      get :index, format: :json, layout: 'projectset'
      r = JSON.parse(response.body)['deliverables_by_user']
      expect(r['myps']['pn1'][0]['id']).to eq @d1.id
      expect(r['myps2']['pn1'][0]['id']).to eq @d1.id
      expect(r['[none]']['pn2'][0]['id']).to eq @d2.id
    end
    it "should secure by project_deliverable" do
      ProjectDeliverable.stub(:search_secure).and_return ProjectDeliverable.where(id:@d1.id)
      get :index, format: :json
      expect(response).to be_success
      r = JSON.parse(response.body)['deliverables_by_user']
      expect(r[@u1.full_name]['pn1'][0]['id']).to eq @d1.id
      expect(r.size).to eq 1
    end
  end
  describe :create do
    it "should create" do
      Project.any_instance.stub(:can_edit?).and_return true
      p = Factory(:project)
      post :create, project_id:p.id, project_deliverable:{description:'desc'}
      expect(response).to be_success

      p.reload
      expect(p.project_deliverables.size).to eq 1
      pd = p.project_deliverables.first
      expect(pd.description).to eq 'desc'
      
      r = JSON.parse(response.body)
      expect(r['project_deliverable']['id']).to eq pd.id
      expect(r['project_deliverable']['project_id']).to eq pd.project_id
    end
    it "should return 401 if user cannot edit project_update" do
      Project.any_instance.stub(:can_edit?).and_return false
      p = Factory(:project)
      post :create, project_id:p.id, project_deliverable:{body:'abc'}
      p.reload
      expect(p.project_deliverables).to be_empty
      expect(response.status).to eq 401
      expect(JSON.parse(response.body)['error']).to match /permission/
    end
  end
  describe :update do
    it "should reject if user cannot edit" do
      Project.any_instance.stub(:can_edit?).and_return false
      pd = Factory(:project_deliverable,description:'x')
      put :update, project_id:pd.project_id, id:pd.id, project_update:{id:pd.id,description:'y'}
      expect(response.status).to eq 401
      expect(JSON.parse(response.body)['error']).to match /permission/ 
      pd.reload
      expect(pd.description).to eq 'x'
    end
    it "should update if user has permission" do
      Project.any_instance.stub(:can_edit?).and_return true
      pd = Factory(:project_deliverable,description:'x')
      put :update, project_id:pd.project_id, id:pd.id, project_deliverable:{id:pd.id,description:'y'}
      pd.reload
      expect(pd.description).to eq 'y'
      expect(response).to be_success
      expect(JSON.parse(response.body)['project_deliverable']['description']).to eq 'y'
    end
  end
end
