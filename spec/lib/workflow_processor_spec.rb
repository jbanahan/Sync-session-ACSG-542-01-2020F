require 'spec_helper'

describe OpenChain::WorkflowProcessor do
  describe :process do
    before :each do
      @mock_stat_client = double('stat_client')
      @mock_stat_client.stub(:wall_time).and_yield
    end
    it "should process multiple workflows for the right module" do
      wp = described_class.new(stat_client: @mock_stat_client)
      ms = MasterSetup.get
      ms.update_attributes(workflow_classes:"OpenChain::CustomHandler::LumberLiquidators::LumberOrderWorkflowDecider\nOpenChain::CustomHandler::JJill::JJillOrderApprovalWorkflowDecider")
      u = User.new
      o = Factory(:order)

      [
        OpenChain::CustomHandler::LumberLiquidators::LumberOrderWorkflowDecider,
        OpenChain::CustomHandler::JJill::JJillOrderApprovalWorkflowDecider
      ].each do |c|
        c.should_receive(:update_workflow!).with(o,u)
      end

      wp.process! o, u
      expect(o.workflow_processor_run.finished_at > 10.seconds.ago).to be_true
    end
    it "should handle change in WorkflowClasses" do
      wp = described_class.new(stat_client: @mock_stat_client)
      ms = MasterSetup.get
      ms.update_attributes(workflow_classes:"OpenChain::CustomHandler::LumberLiquidators::LumberOrderWorkflowDecider\nOpenChain::CustomHandler::JJill::JJillOrderApprovalWorkflowDecider")
      u = User.new
      o = Factory(:order)
      OpenChain::CustomHandler::JJill::JJillOrderApprovalWorkflowDecider.should_receive(:update_workflow!).with(o,u)
      OpenChain::CustomHandler::LumberLiquidators::LumberOrderWorkflowDecider.should_receive(:update_workflow!).with(o,u).twice
      wp.process! o, u
      ms.update_attributes(
        workflow_classes:"OpenChain::CustomHandler::LumberLiquidators::LumberOrderWorkflowDecider",
        updated_at: 1.minute.from_now #force this to be later so we don't run twice in the same second
      )

      wp.process! o, u #second time should reload cache with update master setup
    end
    it "should report processing time to stats server" do
      u = User.new
      o = Factory(:order)
      MasterSetup.get.update_attributes(
        workflow_classes:"OpenChain::CustomHandler::LumberLiquidators::LumberOrderWorkflowDecider"
      )
      OpenChain::CustomHandler::LumberLiquidators::LumberOrderWorkflowDecider.stub(:update_workflow!)
      @mock_stat_client.should_receive(:wall_time).with('wf_processor').and_yield
      described_class.new(stat_client: @mock_stat_client).process! o, u
    end
  end
end