require 'spec_helper'

describe Api::V1::WorkflowController do
  before :each do
    @u = Factory(:user)
    allow_api_access @u
  end
  describe :assign do
    before :each do
      @group = Factory(:group)
      @group.users << @u
      @wt = Factory(:workflow_task,group:@group)
      WorkflowTask.any_instance.stub(:can_edit?).and_return true
    end
    it "should assign" do
      put :assign, user_id: @u.id.to_s, id: @wt.id
      expect(response).to be_success
      @wt.reload
      expect(@wt.assigned_to).to eq @u
    end
    it "should not allow assignment if current_user cannot edit" do
      WorkflowTask.any_instance.stub(:can_edit?).and_return false
      put :assign, user_id: @u.id.to_s, id: @wt.id
      expect(response.status).to eq 401
      expect(JSON.parse(response.body)['errors']).to_not be_empty
      @wt.reload
      expect(@wt.assigned_to).to be_nil
    end
    it "should not allow assignment if assignment user cannot edit" do
      u2 = Factory(:user)
      WorkflowTask.any_instance.should_receive(:can_edit?).twice.and_return(true,false)
      put :assign, user_id: u2.id.to_s, id: @wt.id
      expect(JSON.parse(response.body)['errors']).to_not be_empty
      @wt.reload
      expect(@wt.assigned_to).to be_nil
    end
    it "should turn off assignment if nil" do
      @wt.update_attributes(assigned_to_id:@u.id)
      put :assign, id: @wt.id
      expect(response).to be_success
      @wt.reload
      expect(@wt.assigned_to).to be_nil
    end
  end
  describe :set_multi_state do
    before :each do
      @wt = Factory(:workflow_task,test_class_name:'OpenChain::WorkflowTester::MultiStateWorkflowTest',payload_json:'{"state_options":["yes","no"]}')
      @mp = double(:mock_processor)
      @mp.stub(:process!)
      OpenChain::WorkflowProcessor.stub(:new).and_return(@mp)
    end
    it "should update state" do
      WorkflowTask.any_instance.stub(:can_edit?).and_return true
      @mp.should_receive(:process!).with(@wt.workflow_instance.base_object,@u)
      put :set_multi_state, id: @wt.id, state: 'yes'
      @wt.reload
      expect(@wt.multi_state_workflow_task.state).to eq 'yes'
      expect(response).to be_success
      expected_resp = {'state'=>'yes'}
      expect(JSON.parse(response.body)).to eq expected_resp
    end
    it "should reject if user cannot edit workflow task" do
      WorkflowTask.any_instance.stub(:can_edit?).and_return false
      put :set_multi_state, id: @wt.id, state: 'yes'
      @wt.reload
      expect(@wt.multi_state_workflow_task).to be_nil
      expect(JSON.parse(response.body)['errors']).to_not be_empty
    end
    it "should reject if state is not in options list" do
      WorkflowTask.any_instance.stub(:can_edit?).and_return true
      put :set_multi_state, id: @wt.id, state: 'other'
      @wt.reload
      expect(@wt.multi_state_workflow_task).to be_nil
      expect(JSON.parse(response.body)['errors']).to_not be_empty
    end
  end
  describe :my_instance_open_task_count do
    it "should get the number of incomplete tasks for the current user for the base object in question" do
      Order.any_instance.stub(:can_view?).and_return true
      g = Factory(:group)
      g.users << @u
      o = Factory(:order)
      wt1 = Factory(:workflow_task,workflow_instance:Factory(:workflow_instance,base_object:o),group:g)
      wt2 = Factory(:workflow_task,workflow_instance:wt1.workflow_instance,group:g)
      wt_not_found = Factory(:workflow_task,workflow_instance:wt1.workflow_instance)
      get :my_instance_open_task_count, core_module:'Order', id:o.id.to_s
      expect(JSON.parse(response.body)['count']).to eq 2
    end
  end
end