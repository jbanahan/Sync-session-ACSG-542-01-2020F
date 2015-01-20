require 'spec_helper'

describe OpenChain::WorkflowProcessor do
  def wp_without_stat
    described_class.new(stat_client:@mock_stat_client)
  end
  before :each do
    @mock_stat_client = double('stat_client')
    @mock_stat_client.stub(:wall_time).and_yield
  end

  describe :process_all! do
    it "should get all classes and process" do
      k1 = Company
      k2 = Order
      decider_hash = {k1=>['x'],k2=>['y']}
      described_class.should_receive(:prep_decider_hash).and_return(decider_hash)
      opts = {}
      u = User.new
      described_class.should_receive(:process_class!).with(k1,u,opts)
      described_class.should_receive(:process_class!).with(k2,u,opts)

      described_class.process_all! u, opts
    end
  end

  describe :process_class! do
    it "should get objects and process all" do
      obj1 = double('obj1')
      obj2 = double('obj2')
      k = Company
      opts = {stat_client:@mock_stat_client}
      u = User.new
      described_class.should_receive(:objects_need_processing).with(k).and_return [obj1,obj2]
      wp = double('wp')
      wp.should_receive(:process!).with(obj1,u)
      wp.should_receive(:process!).with(obj2,u)
      described_class.should_receive(:new).with(opts).and_return(wp)
      
      described_class.process_class! k, u, opts
    end
  end
  describe :objects_need_processing do
    before :each do
      #making an object that doesn't need processing and 
      #that shouldn't be found by any of the tests
      dont_find_me = Factory(:order,updated_at:2.hours.ago)
      dont_find_me.create_workflow_processor_run!(finished_at:1.hour.ago)
    end
    it "should find where updated_at > workflow_processor_run" do
      o = Factory(:order,updated_at:1.hour.ago)
      o.create_workflow_processor_run!(finished_at:2.hours.ago)
      expect(described_class.objects_need_processing(Order).to_a).to eq [o]
    end
    it "should find where workflow_task > workflow_processor_run" do
      o = Factory(:order,updated_at:1.year.ago)
      o.create_workflow_processor_run!(finished_at:2.hours.ago)
      wt = Factory(:workflow_task,workflow_instance:Factory(:workflow_instance,base_object:o),updated_at:1.hour.ago)
      expect(described_class.objects_need_processing(Order).to_a).to eq [o]
    end
    it "should find where custom_value > workflow_processor_run" do
      o = Factory(:order,updated_at:3.hour.ago)
      o.create_workflow_processor_run!(finished_at:2.hours.ago)
      cd = Factory(:custom_definition,data_type: :string)
      o.update_custom_value!(cd,'abc')
      expect(o.updated_at).to be < 1.hour.ago
      expect(described_class.objects_need_processing(Order).to_a).to eq [o]
    end
    it "should find where there isn't a workflow_processor_run" do
      o = Factory(:order,updated_at:1.hour.ago)
      expect(described_class.objects_need_processing(Order).to_a).to eq [o]
    end
    it "should not find where no custom_value and updated_at < workflow_processor_run" do
      o = Factory(:order,updated_at:3.hour.ago)
      o.create_workflow_processor_run!(finished_at:2.hours.ago)
      expect(described_class.objects_need_processing(Order)).to be_empty
    end
  end
  describe :process do
    it "should process multiple workflows for the right module" do
      wp = wp_without_stat
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
      wp = wp_without_stat
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
      wp_without_stat.process! o, u
    end
  end
end