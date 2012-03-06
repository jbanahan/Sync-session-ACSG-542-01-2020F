require 'spec_helper'

describe Answer do
  it "should require survey_response" do
    a = Answer.new(:question=>Factory(:question))
    a.save.should be_false
  end
  it "should require question" do
    a = Answer.new(:survey_response=>Factory(:survey_response))
    a.save.should be_false
  end
end
