require 'spec_helper'

describe Question do
  it "should touch parent survey" do
    q = Factory(:question)
    s = q.survey
    s.update_attributes(:updated_at=>1.day.ago)
    Survey.find(s.id).updated_at.should < 23.hours.ago
    q.update_attributes(:content=>'123456489121351')
    Survey.find(s.id).updated_at.should > 1.minute.ago
  end
  it "should not save if parent survey is locked" do
    s = Factory(:survey)
    q = Factory(:question,:survey=>s)
    Survey.any_instance.stub(:locked?).and_return(:true)
    q.content = 'some content length'
    q.save.should be_false
    q.errors.full_messages.first.should == "Cannot save question because survey is missing or locked."
  end
  it "should require parent survey" do
    q = Question.new(:content=>'abc')
    q.save.should be_false
  end
  it "should require content" do
    s = Factory(:survey)
    q = Question.new(:survey_id=>s.id)
    q.save.should be_false
  end
  it "should default scope to sort by rank then id" do
    s = Factory(:survey)
    q_10 = s.questions.create!(:content=>"1234567890",:rank=>10)
    q_1 = s.questions.create!(:content=>"12345647879",:rank=>1)
    q_1_2 = s.questions.create!(:content=>"12345678901",:rank=>1)
    sorted = Survey.find(s.id).questions.to_a
    sorted[0].should == q_1
    sorted[1].should == q_1_2
    sorted[2].should == q_10
  end
end
