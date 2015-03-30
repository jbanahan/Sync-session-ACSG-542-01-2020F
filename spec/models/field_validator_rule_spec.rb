require 'spec_helper'

describe FieldValidatorRule do
  describe "max length" do
    before :each do
      FieldValidatorRule.create!(:model_field_uid=>"ord_ord_num",:maximum_length=>3,:custom_message=>"1010")
      @f = FieldValidatorRule.first
    end
    it "should pass for valid values" do
      ["abc","ab","",nil].each do |v|
        @f.validate_input(v).should be_empty
      end
    end
    it "should fail for longer string" do
      @f.validate_input("abcd").first.should == @f.custom_message
    end
  end

  describe "view_groups" do
    it "returns a sorted list of view groups" do
      r = FieldValidatorRule.new can_view_groups: "Z\r\nY\nA"
      expect(r.view_groups).to eq ["A", "Y", "Z"]
    end
  end

  describe "edit_groups" do
    it "returns a sorted list of view groups" do
      r = FieldValidatorRule.new can_edit_groups: "Z\r\nY\nA"
      expect(r.edit_groups).to eq ["A", "Y", "Z"]
    end
  end
end
