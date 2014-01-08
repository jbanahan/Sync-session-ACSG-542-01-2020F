require 'spec_helper'

describe ProjectUpdatesController do
  before :each do
    @u = Factory(:master_user,project_view:true,project_edit:true)
    MasterSetup.get.update_attributes(project_enabled:true)
    activate_authlogic
    UserSession.create! @u
  end
  describe :index do
    it "should show all updates by project" do
      Project.any_instance.stub(:can_view?).and_return true
      pu1 = Factory(:project_update)
      pu2 = Factory(:project_update,project:pu1.project)
      Factory(:project_update)
      get :index, project_id:pu1.project.id
      expect(response).to be_success
      r = JSON.parse response.body
      expect(r['project_updates'].size).to eq 2
      r['project_updates'].each {|pu| expect(pu['project_id']).to eq pu1.project.id}
    end
    it "should return 401 if user cannot view project" do
      Project.any_instance.stub(:can_view?).and_return false
      pu1 = Factory(:project_update)
      get :index, project_id:pu1.project.id
      expect(response.status).to eq 401
      expect(JSON.parse(response.body)['error']).to match /permission/
    end
  end
  describe :create do
    it "should set created_by" do
      Project.any_instance.stub(:can_edit?).and_return true
      p = Factory(:project)
      post :create, project_id:p.id, project_update:{body:'abc'}
      expect(response).to be_success

      p.reload
      expect(p.project_updates.size).to eq 1
      pu = p.project_updates.first
      expect(pu.body).to eq 'abc'
      expect(pu.created_by).to eq @u
      
      r = JSON.parse(response.body)
      expect(r['project_update']['id']).to eq pu.id
      expect(r['project_update']['created_by_id']).to eq pu.created_by_id
      expect(r['project_update']['project_id']).to eq pu.project_id
    end
    it "should return 401 if user cannot edit project_update" do
      Project.any_instance.stub(:can_edit?).and_return false
      p = Factory(:project)
      post :create, project_id:p.id, project_update:{body:'abc'}
      p.reload
      expect(p.project_updates).to be_empty
      expect(response.status).to eq 401
      expect(JSON.parse(response.body)['error']).to match /permission/
    end
  end
  describe :update do
    it "should reject if user is not created_by" do
      pu = Factory(:project_update,created_by:@u,body:'x')
      put :update, project_id:p.id, id:pu.id, project_update:{id:pu.id,body:'y'}
      pu.reload
      expect(pu.body).to eq 'y'
      expect(response).to be_success
      expect(JSON.parse(response.body)['project_update']['body']).to eq 'y'
    end
    it "should update if user is created_by"
  end
end
