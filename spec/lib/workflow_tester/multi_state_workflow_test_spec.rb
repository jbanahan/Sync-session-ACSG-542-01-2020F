require 'spec_helper'

describe OpenChain::WorkflowTester::MultiStateWorkflowTest do
  describe :category do
    it "should return Actions" do
      expect(described_class.category).to eq 'Actions'
    end
  end
  describe :pass? do
    before :each do
      @wt = Factory(:workflow_task,test_class_name:described_class.name)
    end
    it "should return false if no MultiStateWorkflowTask" do
      expect(described_class.pass?(@wt)).to be_false
    end
    it "should return true if MultiStateWorkflowTask has a non-blank state value" do
      ms = @wt.create_multi_state_workflow_task!(state:'something')
      expect(described_class.pass?(@wt)).to be_true
    end
    it "should return false if MultiStateWorkflowTask has a blank state value" do
      ms = @wt.create_multi_state_workflow_task!
      expect(described_class.pass?(@wt)).to be_false
    end
  end
end