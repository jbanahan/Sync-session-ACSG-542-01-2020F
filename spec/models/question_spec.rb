require 'spec_helper'

describe Question do
  it 'should default sort by rank' do
    q2 = Factory(:question,:rank=>2)
    q1 = Factory(:question,:rank=>1)
    Question.all.should == [q1,q2]
  end
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
  it 'should allow one or more attachments' do
    s = Factory(:survey)
    q = Question.new(survey_id: s.id, content: "Sample content of a question.")
    q.save!
    q.attachments.create!(attached_file_name:"attachment1.jpg")
    q.attachments.create!(attached_file_name:"attachment2.jpg")
    q.attachments.length.should == 2
  end
  it 'should not allow downloads if user does not have permission' do
    u = User.new
    s = Factory(:survey)
    q = Question.new(survey_id: s.id, content: "Sample content of a question.")
    q.save!
    (q.can_view?(u)).should be_false
  end
  it 'should allow downloads for creator of the survey' do
    ## In this case, the user in question is the survey creator
    user = Factory(:user, survey_edit: true)
    survey = Factory(:survey, created_by_id: user.id, company_id: user.company_id)
    question = Question.new(survey_id: survey.id, content: "Sample content of a question.")
    (question.can_view?(user)).should be_true
  end
  it 'should allow downloads for viewers of the response' do
    ## In this case, the user in question is a viewer of the survey response
    user = Factory(:user)
    survey = Factory(:survey, created_by_id: user.id)
    question = Question.new(survey_id: survey.id, content: "Sample content of a question.")
    survey_response = Factory(:survey_response, survey: survey, user_id: user.id)
    (question.can_view?(user)).should be_true
  end
end
