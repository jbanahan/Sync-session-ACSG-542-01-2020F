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
      @d1 = Factory(:project_deliverable)
      @d2 = Factory(:project_deliverable)
      @d3 = Factory(:project_deliverable,complete:true)
    end
    it "should return all incomplete" do
      get :index
      expect(response).to be_success
      d = assigns(:deliverables)
      expect(d.order(:id).to_a).to eq [@d1,@d2]
    end
    it "should error if user cannot view projects" do
      User.any_instance.stub(:view_projects?).and_return false
      get :index
      expect(response).to be_redirect
      expect(flash[:errors].first).to match /permission/
    end
    it "should secure by project_deliverable" do
      ProjectDeliverable.stub(:search_secure).and_return ProjectDeliverable.where(id:@d1.id)
      get :index
      expect(response).to be_success
      d = assigns(:deliverables)
      expect(d.to_a).to eq [@d1]
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
