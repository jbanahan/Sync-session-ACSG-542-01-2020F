require 'spec_helper'

describe ProjectUpdatesController do
  before :each do
    @u = Factory(:master_user,project_view:true,project_edit:true)
    MasterSetup.get.update_attributes(project_enabled:true)

    sign_in_as @u
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
      pu = Factory(:project_update,created_by:Factory(:user),body:'x')
      put :update, project_id:pu.project_id, id:pu.id, project_update:{id:pu.id,body:'y'}
      expect(response.status).to eq 401
      expect(JSON.parse(response.body)['error']).to eq "You cannot edit updates unless you created them."
      pu.reload
      expect(pu.body).to eq 'x'
    end
    it "should update if user is created_by" do
      pu = Factory(:project_update,created_by:@u,body:'x')
      put :update, project_id:pu.project_id, id:pu.id, project_update:{id:pu.id,body:'y'}
      pu.reload
      expect(pu.body).to eq 'y'
      expect(response).to be_success
      expect(JSON.parse(response.body)['project_update']['body']).to eq 'y'
    end
  end
end
