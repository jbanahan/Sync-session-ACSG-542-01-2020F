require 'spec_helper'

describe WorkflowTask do
  module OpenChain; module Test; class MyTestWorkflowTask
    def self.pass? wt
      wt.payload['pass']
    end
  end; end; end
  describe :test_class do
    it "should get test class" do
      wt = WorkflowTask.new(test_class_name:"OpenChain::Test::MyTestWorkflowTask")
      expect(wt.test_class).to eq OpenChain::Test::MyTestWorkflowTask
    end
  end
  describe :test! do
    it "should use test class and set passed" do
      wt = Factory(:workflow_task,test_class_name:"OpenChain::Test::MyTestWorkflowTask",payload_json:'{"pass":"yes"}')
      expect(wt.passed_at).to be_nil
      expect(wt.test!).to be_true
      expect(wt.passed_at).to_not be_nil

    end
    it "should use test class and clear passed" do
      wt = Factory(:workflow_task,test_class_name:"OpenChain::Test::MyTestWorkflowTask",payload_json:'{"a":"b"}',passed_at:Time.now)
      expect(wt.passed_at).to_not be_nil
      expect(wt.test!).to be_false
      expect(wt.passed_at).to be_nil
    end
  end
end
