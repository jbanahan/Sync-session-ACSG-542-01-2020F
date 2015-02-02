require 'spec_helper'

describe OpenChain::WorkflowTester::SurveyCompleteWorkflowTest do
  describe :pass? do
    before :each do
      @o = Factory(:order)
      @wt = Factory(:workflow_task,payload_json:'{"survey_code":"SRX","survey_rating":"ABC"}',workflow_instance:Factory(:workflow_instance,base_object:@o))
    end
    it "should pass if survey exists by survey_code and survey rating is survey_rating" do
      sr = Factory(:survey_response,survey:Factory(:survey,system_code:'SRX'),rating:'ABC',base_object:@wt.base_object)
      expect(described_class.pass?(@wt)).to be_true
    end
    it "should not pass if survey with system_code does not exists" do
      sr = Factory(:survey_response,survey:Factory(:survey,system_code:'Other'),rating:'ABC',base_object:@wt.base_object)
      expect(described_class.pass?(@wt)).to be_false
    end
    it "should not pass if survey rating is different" do
      sr = Factory(:survey_response,survey:Factory(:survey,system_code:'SRX'),rating:'Other',base_object:@wt.base_object)
      expect(described_class.pass?(@wt)).to be_false
    end
  end
end