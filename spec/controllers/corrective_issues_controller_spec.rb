require 'spec_helper'

describe CorrectiveIssuesController do
  before :each do
    @u = Factory(:user)

    sign_in_as @u
    @cap = Factory(:corrective_action_plan)
    CorrectiveActionPlan.any_instance.stub(:can_view?).and_return(true)
  end

  describe :update do
    it "should allow editor to update description and suggested action" do
      ci = @cap.corrective_issues.create!(description:'d',suggested_action:'sa',action_taken:'at')
      CorrectiveActionPlan.any_instance.stub(:can_edit?).and_return(true)
      CorrectiveActionPlan.any_instance.stub(:can_update_actions?).and_return(false)
      put :update, :id=>ci.id.to_s, 'corrective_issue'=>{'id'=>ci.id.to_s,'description'=>'nd','suggested_action'=>'ns','action_taken'=>'na'}, :format=> 'json'
      ci.reload
      ci.description.should == 'nd'
      ci.suggested_action.should == 'ns'
      ci.action_taken.should == 'at' #not changed
    end
    it "should allow assigned user to update action taken" do
      ci = @cap.corrective_issues.create!(description:'d',suggested_action:'sa',action_taken:'at')
      CorrectiveActionPlan.any_instance.stub(:can_edit?).and_return(false)
      CorrectiveActionPlan.any_instance.stub(:can_update_actions?).and_return(true)
      put :update, :id=>ci.id.to_s, 'corrective_issue'=>{'id'=>ci.id.to_s,'description'=>'nd','suggested_action'=>'ns','action_taken'=>'na'}, :format=> 'json'
      ci.reload
      ci.description.should == 'd' #not changed
      ci.suggested_action.should == 'sa' #not changed
      ci.action_taken.should == 'na'
    end
    it "should 401 if user cannot view" do
      CorrectiveActionPlan.any_instance.stub(:can_view?).and_return(false)
      ci = @cap.corrective_issues.create!(description:'d',suggested_action:'sa',action_taken:'at')
      put :update, :id=>ci.id.to_s, 'corrective_issue'=>{'id'=>ci.id.to_s,'description'=>'nd','suggested_action'=>'ns','action_taken'=>'na'}, :format=> 'json'
      response.status.should == 401
    end
    it "should log update" do
      ci = @cap.corrective_issues.create!(description:'d',suggested_action:'sa',action_taken:'at')
      CorrectiveActionPlan.any_instance.stub(:can_edit?).and_return(false)
      CorrectiveActionPlan.any_instance.stub(:can_update_actions?).and_return(true)

      CorrectiveActionPlan.any_instance.should_receive(:log_update).with(@u)
      put :update, :id=>ci.id.to_s, 'corrective_issue'=>{'id'=>ci.id.to_s,'description'=>'nd','suggested_action'=>'ns','action_taken'=>'na'}, :format=> 'json'
    end
  end

  describe 'create' do
    it "should allow create if user can edit plan" do
      CorrectiveActionPlan.any_instance.stub(:can_edit?).and_return true
      post :create, :corrective_action_plan_id=>@cap.id.to_s
      response.should be_success
      JSON.parse(response.body)['corrective_issue']['id'].to_i.should > 0
      @cap.should have(1).corrective_issues
    end
    it "should not allow create if user cannot edit plan" do
      CorrectiveActionPlan.any_instance.stub(:can_edit?).and_return false
      post :create, :corrective_action_plan_id=>@cap.id.to_s
      response.status.should == 401
      @cap.corrective_issues.should be_empty
    end
  end

  describe 'update_resolution_status' do
    it 'should allow update if user can edit the parent plan' do
      CorrectiveActionPlan.any_instance.stub(:can_edit?).and_return true
      ci = @cap.corrective_issues.create!

      #set it from nil to true
      post :update_resolution_status, id: ci.id.to_s, is_resolved: true, format: :json
      ci.reload
      ci.resolved.should == true

      #set it from true to false
      post :update_resolution_status, id: ci.id.to_s, is_resolved: false, format: :json
      ci.reload
      ci.resolved.should == false
    end

    it 'should not allow update if user can not edit the parent plan' do
      CorrectiveActionPlan.any_instance.stub(:can_edit?).and_return false
      ci = @cap.corrective_issues.create!
      ci.resolved = false; ci.save!

      #try setting it from false to true (should reject and remain false)
      post :update_resolution_status, id: ci.id.to_s, is_resolved: true, format: :json
      ci.reload
      ci.resolved.should == false

      ci.resolved = true; ci.save!
      
      #try setting it from true to false (should reject and remain true)
      post :update_resolution_status, id: ci.id.to_s, is_resolved: false, format: :json
      ci.reload
      ci.resolved.should == true
    end

  end
  describe 'destroy' do
    it "should allow destroy if user can edit plan and plan is new" do
      CorrectiveActionPlan.any_instance.stub(:can_edit?).and_return true
      @cap.update_attributes(status:CorrectiveActionPlan::STATUSES[:new])
      ci = @cap.corrective_issues.create!
      delete :destroy, id: ci.id.to_s, format: :json
      response.should be_success
      CorrectiveIssue.find_by_id(ci.id).should be_nil
    end
    it "should not allow destroy if plan is not new" do
      CorrectiveActionPlan.any_instance.stub(:can_edit?).and_return true
      @cap.update_attributes(status:CorrectiveActionPlan::STATUSES[:active])
      ci = @cap.corrective_issues.create!
      delete :destroy, id: ci.id.to_s, format: :json
      response.status.should == 400
      CorrectiveIssue.find_by_id(ci.id).should_not be_nil
    end
    it "should not allow destroy if user cannot edit" do
      CorrectiveActionPlan.any_instance.stub(:can_edit?).and_return false
      @cap.update_attributes(status:CorrectiveActionPlan::STATUSES[:new])
      ci = @cap.corrective_issues.create!
      delete :destroy, id: ci.id.to_s, format: :json
      response.status.should == 401
      CorrectiveIssue.find_by_id(ci.id).should_not be_nil
    end
  end
end
