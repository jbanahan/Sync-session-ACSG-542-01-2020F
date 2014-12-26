require 'spec_helper'

describe Api::V1::WorkflowController do
  before :each do
    @u = Factory(:user)
    allow_api_access @u
  end
  describe :set_multi_state do
    before :each do
      @wt = Factory(:workflow_task,test_class_name:'OpenChain::WorkflowTester::MultiStateWorkflowTest',payload_json:'{"state_options":["yes","no"]}')
    end
    it "should update state" do
      WorkflowTask.any_instance.stub(:can_edit?).and_return true
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