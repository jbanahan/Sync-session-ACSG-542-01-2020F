require 'spec_helper'

describe OpenChain::WorkflowTester::ModelFieldWorkflowTest do
  describe "category" do
    it "should return Data" do
      expect(described_class.category).to eq 'Data'
    end
  end
  describe "pass?" do
    before :each do
      @c = Company.new(name:'Joe',system_code:'ABCDEF')
      @t = Factory(:workflow_task,test_class_name:'OpenChain::WorkflowTester::ModelFieldWorkflowTest',payload_json:'{"model_fields":[{"uid":"cmp_name","regex":"Joe"},{"uid":"cmp_sys_code"}]}',workflow_instance:Factory(:workflow_instance,base_object:@c))
    end
    it "should pass if meets all model field tests" do
      expect(described_class.pass?(@t)).to be_truthy
    end
    it "should fail if model field is empty" do
      @c.update_attributes(system_code:nil)
      expect(described_class.pass?(@t)).to be_falsey
    end
    it "should fail if model field doesn't match regex" do
      @c.update_attributes(name:'FRED')
      expect(described_class.pass?(@t)).to be_falsey
    end
    it "should test target_object" do
      plnt = Factory(:plant,company:@c,name:'Plant Name')
      @t.target_object = plnt
      @t.payload_json = '{"model_fields":[{"uid":"plant_name","regex":"Plant Name"}]}'
      @t.save!
      expect(described_class.pass?(@t)).to be_truthy
    end
  end
end