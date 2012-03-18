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
  it "should protect date attributes" do
    sr = Factory(:survey_response)
    d = 1.day.ago
    d2 = 2.days.ago
    sr.email_sent_date = d
    sr.email_opened_date = d
    sr.response_opened_date = d
    sr.submitted_date = d
    sr.accepted_date = d

    sr.update_attributes(:updated_at=>d2,:email_sent_date=>d2,:email_opened_date=>d2,
      :response_opened_date=>d2,:submitted_date=>d2,:accepted_date=>d2)

    found = SurveyResponse.find sr.id
    found.email_sent_date.to_i.should == d.to_i
    found.email_opened_date.to_i.should == d.to_i
    found.response_opened_date.to_i.should == d.to_i
    found.submitted_date.to_i.should == d.to_i
    found.accepted_date.to_i.should == d.to_i
    found.updated_at.to_i.should == d2.to_i #this one isn't protected
  end
  describe "status" do
    before :each do
      s = Factory(:survey)
      q1 = Factory(:question,:survey=>s)
      q2 = Factory(:question,:survey=>s)
      u = Factory(:user)
      @sr = s.generate_response! u
    end
    it "should have Incomplete status" do
      @sr.status.should == "Incomplete"
    end
    it "should have Not Rated" do
      @sr.submitted_date = 0.seconds.ago
      @sr.save!
      @sr.status.should == "Not Rated"
    end
    it "should have Needs Improvement status" do
      # if any responses are NI then whole status is NI
      @sr.submitted_date = 0.seconds.ago
      @sr.answers.first.update_attributes(:rating=>"Needs Improvement")
      @sr.save!
      @sr.status.should == "Needs Improvement"
    end
    it "should have Accepted status" do
      # if all ratings are accepted then whole status Accepted
      @sr.submitted_date = 0.seconds.ago
      @sr.answers.each {|a| a.update_attributes(:rating=>"Accepted")}
      @sr.save!
      @sr.status.should == "Accepted"
    end
  end
end
