require 'spec_helper'

describe OpenChain::WorkflowDecider do
  describe "update_workflow!" do
    before :each do
      @k = Class.new do
        extend OpenChain::WorkflowDecider

        def self.do_workflow! o, w, u
        end
      end
      @k.stub(:name).and_return "MyWorkflowDecider"
      @o = Factory(:order)
      @u = double('user')
    end
    it "should call do_workflow" do
      @k.should_receive(:do_workflow!).with(@o,instance_of(WorkflowInstance),@u)
      @k.update_workflow! @o, @u
    end
    it "should lock on base_object" do
      @o.should_receive(:id).and_return 10
      Lock.should_receive(:acquire).with('Workflow-Order-10',{temp_lock:true}).and_yield
      @k.update_workflow! @o, @u
    end
    it "should create workflow instance" do
      expect {@k.update_workflow!(@o,@u)}.to change(WorkflowInstance,:count).from(0).to(1)
      @o.reload
      expect(@o.workflow_instances.where(workflow_decider_class:"MyWorkflowDecider").count).to eq 1
    end
    it "should find existing workflow instance" do
      expect {@k.update_workflow!(@o,@u)}.to change(WorkflowInstance,:count).from(0).to(1)
      expect {@k.update_workflow!(@o,@u)}.to_not change(WorkflowInstance,:count)
    end
  end
end