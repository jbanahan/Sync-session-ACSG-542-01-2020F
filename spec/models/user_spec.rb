require 'spec_helper'

describe User do
  context "permissions" do
    it "should pass view_surveys?" do
      User.new(:survey_view=>true).view_surveys?.should be_true
    end
    it "should pass edit_surveys?" do
      User.new(:survey_edit=>true).edit_surveys?.should be_true
    end
    it "should fail view_surveys?" do
      User.new(:survey_view=>false).view_surveys?.should be_false
    end
    it "should fail edit_surveys?" do
      User.new(:survey_edit=>false).edit_surveys?.should be_false
    end
  end
end
