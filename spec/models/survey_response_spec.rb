require 'spec_helper'

describe SurveyResponse do
  it "should require survey" do
    sr = SurveyResponse.new(:user=>Factory(:user))
    sr.save.should be_false
  end
  it "should require user" do
    sr = SurveyResponse.new(:survey=>Factory(:survey))
    sr.save.should be_false
  end
  it "should accept nested attributes for answers" do
    s = Factory(:survey)
    s.questions.create!(:content=>'1234567890123',:rank=>1)
    q = s.questions.first
    sr = Factory(:survey_response,:survey=>s)
    sr.update_attributes(:answers_attributes=>[{:question_id=>q.id,:choice=>'123',:rating=>'NI'}])
    a = sr.answers.first
    a.question.should == q
    a.choice.should == '123'
    a.rating.should == 'NI'
  end
end
