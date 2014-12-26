require 'spec_helper'

describe OpenChain::WorkflowTester::AttachmentTypeWorkflowTest do
  describe :category do
    it "should return Attachments" do
      expect(described_class.category).to eq 'Attachments'
    end
  end
  describe :pass? do
    before :each do
      @t = Factory(:workflow_task,test_class_name:'OpenChain::WorkflowTester::AttachmentTypeWorkflowTest',payload_json:'{"attachment_type":"Sample"}')
    end
    it "should pass if attachment exists" do
      Factory(:attachment,attachable:@t.workflow_instance.base_object,attachment_type:'Sample')
      @t.reload
      expect(described_class.pass?(@t)).to be_true
    end
    it "should fail if attachment doesn't exist" do
      expect(described_class.pass?(@t)).to be_false
    end
  end
end