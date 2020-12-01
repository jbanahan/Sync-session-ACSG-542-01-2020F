describe CorrectiveIssuesController do
  before :each do
    @u = FactoryBot(:user)

    sign_in_as @u
    @cap = FactoryBot(:corrective_action_plan)
    allow_any_instance_of(CorrectiveActionPlan).to receive(:can_view?).and_return(true)
  end

  describe "update" do
    it "should allow editor to update description and suggested action" do
      ci = @cap.corrective_issues.create!(description:'d', suggested_action:'sa', action_taken:'at')
      allow_any_instance_of(CorrectiveActionPlan).to receive(:can_edit?).and_return(true)
      allow_any_instance_of(CorrectiveActionPlan).to receive(:can_update_actions?).and_return(false)
      put :update, :id=>ci.id.to_s, 'corrective_issue'=>{'id'=>ci.id.to_s, 'description'=>'nd', 'suggested_action'=>'ns', 'action_taken'=>'na'}, :format=> 'json'
      ci.reload
      expect(ci.description).to eq('nd')
      expect(ci.suggested_action).to eq('ns')
      expect(ci.action_taken).to eq('at') # not changed
    end
    it "should allow assigned user to update action taken" do
      ci = @cap.corrective_issues.create!(description:'d', suggested_action:'sa', action_taken:'at')
      allow_any_instance_of(CorrectiveActionPlan).to receive(:can_edit?).and_return(false)
      allow_any_instance_of(CorrectiveActionPlan).to receive(:can_update_actions?).and_return(true)
      put :update, :id=>ci.id.to_s, 'corrective_issue'=>{'id'=>ci.id.to_s, 'description'=>'nd', 'suggested_action'=>'ns', 'action_taken'=>'na'}, :format=> 'json'
      ci.reload
      expect(ci.description).to eq('nd') # can change due to updated permission expression
      expect(ci.suggested_action).to eq('ns') # can change due to updated permission expression
      expect(ci.action_taken).to eq('na')
    end
    it "should 401 if user cannot view" do
      allow_any_instance_of(CorrectiveActionPlan).to receive(:can_view?).and_return(false)
      ci = @cap.corrective_issues.create!(description:'d', suggested_action:'sa', action_taken:'at')
      put :update, :id=>ci.id.to_s, 'corrective_issue'=>{'id'=>ci.id.to_s, 'description'=>'nd', 'suggested_action'=>'ns', 'action_taken'=>'na'}, :format=> 'json'
      expect(response.status).to eq(401)
    end
    it "should log update" do
      ci = @cap.corrective_issues.create!(description:'d', suggested_action:'sa', action_taken:'at')
      allow_any_instance_of(CorrectiveActionPlan).to receive(:can_edit?).and_return(false)
      allow_any_instance_of(CorrectiveActionPlan).to receive(:can_update_actions?).and_return(true)

      expect_any_instance_of(CorrectiveActionPlan).to receive(:log_update).with(@u)
      put :update, :id=>ci.id.to_s, 'corrective_issue'=>{'id'=>ci.id.to_s, 'description'=>'nd', 'suggested_action'=>'ns', 'action_taken'=>'na'}, :format=> 'json'
    end
    it "should update extra fields if current_user can edit" do
      ci = @cap.corrective_issues.create!(description:'d', suggested_action:'sa', action_taken:'at')
      allow_any_instance_of(CorrectiveActionPlan).to receive(:can_edit?).and_return(true)
      allow_any_instance_of(CorrectiveActionPlan).to receive(:can_update_actions?).and_return(false)

      put :update, :id=>ci.id.to_s, 'corrective_issue'=>{'id'=>ci.id.to_s, 'description'=>'nd', 'suggested_action'=>'nsa', 'action_taken'=>'nat'}, :format=> 'json'
      r = JSON.parse(response.body)["corrective_issue"]
      expect(r["description"]).to eq("nd")
      expect(r["suggested_action"]).to eq("nsa")
    end

    it "should update extra fields if current_user can update actions" do
      ci = @cap.corrective_issues.create!(description:'d', suggested_action:'sa', action_taken:'at')
      allow_any_instance_of(CorrectiveActionPlan).to receive(:can_edit?).and_return(false)
      allow_any_instance_of(CorrectiveActionPlan).to receive(:can_update_actions?).and_return(true)

      put :update, :id=>ci.id.to_s, 'corrective_issue'=>{'id'=>ci.id.to_s, 'description'=>'nd', 'suggested_action'=>'nsa', 'action_taken'=>'nat'}, :format=> 'json'
      r = JSON.parse(response.body)["corrective_issue"]
      expect(r["description"]).to eq("nd")
      expect(r["suggested_action"]).to eq("nsa")
    end

    it "should not update extra fields if current_user can neither edit nor update actions" do
      ci = @cap.corrective_issues.create!(description:'d', suggested_action:'sa', action_taken:'at')
      allow_any_instance_of(CorrectiveActionPlan).to receive(:can_edit?).and_return(false)
      allow_any_instance_of(CorrectiveActionPlan).to receive(:can_update_actions?).and_return(false)

      put :update, :id=>ci.id.to_s, 'corrective_issue'=>{'id'=>ci.id.to_s, 'description'=>'nd', 'suggested_action'=>'ns', 'action_taken'=>'na'}, :format=> 'json'
      r = JSON.parse(response.body)["corrective_issue"]
      expect(r["description"]).to eq("d")
      expect(r["suggested_action"]).to eq("sa")
    end
  end

  describe 'create' do
    it "should allow create if user can edit plan" do
      allow_any_instance_of(CorrectiveActionPlan).to receive(:can_edit?).and_return true
      post :create, :corrective_action_plan_id=>@cap.id.to_s
      expect(response).to be_success
      expect(JSON.parse(response.body)['corrective_issue']['id'].to_i).to be > 0
      expect(@cap.corrective_issues.size).to eq(1)
    end
    it "should not allow create if user cannot edit plan" do
      allow_any_instance_of(CorrectiveActionPlan).to receive(:can_edit?).and_return false
      post :create, :corrective_action_plan_id=>@cap.id.to_s
      expect(response.status).to eq(401)
      expect(@cap.corrective_issues).to be_empty
    end
  end

  describe 'update_resolution_status' do
    it 'should allow update if user can edit the parent plan' do
      allow_any_instance_of(CorrectiveActionPlan).to receive(:can_edit?).and_return true
      ci = @cap.corrective_issues.create!

      # set it from nil to true
      post :update_resolution_status, id: ci.id.to_s, is_resolved: true, format: :json
      ci.reload
      expect(ci.resolved).to eq(true)

      # set it from true to false
      post :update_resolution_status, id: ci.id.to_s, is_resolved: false, format: :json
      ci.reload
      expect(ci.resolved).to eq(false)
    end

    it 'should not allow update if user can not edit the parent plan' do
      allow_any_instance_of(CorrectiveActionPlan).to receive(:can_edit?).and_return false
      ci = @cap.corrective_issues.create!
      ci.resolved = false; ci.save!

      # try setting it from false to true (should reject and remain false)
      post :update_resolution_status, id: ci.id.to_s, is_resolved: true, format: :json
      ci.reload
      expect(ci.resolved).to eq(false)

      ci.resolved = true; ci.save!

      # try setting it from true to false (should reject and remain true)
      post :update_resolution_status, id: ci.id.to_s, is_resolved: false, format: :json
      ci.reload
      expect(ci.resolved).to eq(true)
    end

  end
  describe 'destroy' do
    it "should allow destroy if user can edit plan and plan is new" do
      allow_any_instance_of(CorrectiveActionPlan).to receive(:can_edit?).and_return true
      @cap.update_attributes(status:CorrectiveActionPlan::STATUSES[:new])
      ci = @cap.corrective_issues.create!
      delete :destroy, id: ci.id.to_s, format: :json
      expect(response).to be_success
      expect(CorrectiveIssue.find_by_id(ci.id)).to be_nil
    end
    it "should not allow destroy if plan is not new" do
      allow_any_instance_of(CorrectiveActionPlan).to receive(:can_edit?).and_return true
      @cap.update_attributes(status:CorrectiveActionPlan::STATUSES[:active])
      ci = @cap.corrective_issues.create!
      delete :destroy, id: ci.id.to_s, format: :json
      expect(response.status).to eq(400)
      expect(CorrectiveIssue.find_by_id(ci.id)).not_to be_nil
    end
    it "should not allow destroy if user cannot edit" do
      allow_any_instance_of(CorrectiveActionPlan).to receive(:can_edit?).and_return false
      @cap.update_attributes(status:CorrectiveActionPlan::STATUSES[:new])
      ci = @cap.corrective_issues.create!
      delete :destroy, id: ci.id.to_s, format: :json
      expect(response.status).to eq(401)
      expect(CorrectiveIssue.find_by_id(ci.id)).not_to be_nil
    end
  end
end
