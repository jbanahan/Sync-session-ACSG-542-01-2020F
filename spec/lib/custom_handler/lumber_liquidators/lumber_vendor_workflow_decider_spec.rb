require 'spec_helper'

describe OpenChain::CustomHandler::LumberLiquidators::LumberVendorWorkflowDecider do
  before :each do
    @ll = Factory(:company,importer:true,system_code:'LUMBER')
    @v = Factory(:company,vendor:true)
    @u = Factory(:user)
  end

  describe :workflow_name do
    it "should return Vendor Setup" do
      expect(described_class.workflow_name).to eq 'Vendor Setup'
    end
  end
  describe :skip? do
    it "should skip non-vendor" do
      expect(described_class.skip?(@ll)).to be_true
      expect(described_class.skip?(@v)).to be_false
      expect{described_class.update_workflow!(@ll,@u)}.to_not change(WorkflowInstance,:count)
    end
  end
end