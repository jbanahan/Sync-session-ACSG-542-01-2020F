require 'spec_helper'

describe Survey do
  describe :copy! do
    before :each do 
      @survey = Factory(:survey,:name=>"my name",:email_subject=>"emlsubj",:email_body=>"emlbod",:ratings_list=>"rat")
    end
    it 'should copy all questions with new ids' do
      q1 = Factory(:question,:rank=>1,:survey_id=>@survey.id,:content=>'my question content 1',:choices=>"x",:warning=>true)
      q2 = Factory(:question,:rank=>2,:survey_id=>@survey.id,:content=>'my question content 2')
      q3 = Factory(:question,:rank=>3,:survey_id=>@survey.id,:content=>'my question content 3')
      new_survey = @survey.copy!
      new_survey.id.should > 0
      new_survey.id.should_not == @survey.id
      new_survey.company_id.should == @survey.company_id
      new_survey.name.should == @survey.name
      new_survey.email_subject.should == @survey.email_subject
      new_survey.email_body.should == @survey.email_body
      new_survey.ratings_list.should == @survey.ratings_list
      new_survey.should have(3).questions
      n1 = new_survey.questions.where(:rank=>1).first
      n1.content.should == q1.content
      n1.choices.should == q1.choices
      n1.warning.should == q1.warning
      new_survey.questions.where(:rank=>2).first.content.should == q2.content
      new_survey.questions.where(:rank=>3).first.content.should == q3.content
    end
    it 'should not copy subscriptions' do
      @survey.survey_subscriptions.create!(:user_id=>Factory(:user).id)
      @survey.copy!.survey_subscriptions.should be_blank
    end
    it 'should not copy assigned users' do
      @survey.generate_response! Factory(:user)
      @survey.copy!.assigned_users.should be_blank
    end
    it 'should not copy responses' do
      @survey.generate_response! Factory(:user)
      @survey.copy!.survey_responses.should be_blank
    end
  end
  it 'should link to user' do
    u = Factory(:user)
    s = Factory(:survey,:created_by_id=>u.id)
    s.created_by.should == u
  end
  it "should be locked if responses exist" do
    sr = Factory(:survey_response)
    sr.survey.should be_locked
  end
  it 'should not allow edits if locked' do
    s = Factory(:survey)
    s.stub(:locked?).and_return(true)
    s.save.should be_false
    s.errors.full_messages.first.should == "You cannot change a locked survey."
  end
  it "should update nested questions" do
    s = Factory(:survey)
    s.update_attributes(:questions_attributes=>[{:content=>'1234567890',:rank=>2},{:content=>"09876543210",:rank=>1}])
    s = Survey.find(s.id)
    s.questions.find_by_content("09876543210").rank.should == 1
    s.questions.find_by_content("1234567890").rank.should == 2
  end
  describe 'generate_response' do
    it 'should make a response with all answers' do
      u = Factory(:user)
      s = Factory(:survey)
      s.update_attributes(:questions_attributes=>[{:content=>'1234567890',:rank=>2},{:content=>"09876543210",:rank=>1}])
      sr = s.generate_response! u
      sr.answers.should have(2).answers
    end
    it 'should log response generation' do
      u = Factory(:user)
      s = Factory(:survey)
      s.update_attributes(:questions_attributes=>[{:content=>'1234567890',:rank=>2},{:content=>"09876543210",:rank=>1}])
      sr = s.generate_response! u
      sr.survey_response_logs.where(:message=>"Survey assigned to #{u.full_name}").should have(1).item
    end
    it 'should set response subtitle' do
      u = Factory(:user)
      s = Factory(:survey)
      s.update_attributes(:questions_attributes=>[{:content=>'1234567890',:rank=>2},{:content=>"09876543210",:rank=>1}])
      sr = s.generate_response! u, 'abc'
      sr.subtitle.should == 'abc'
    end
  end
  describe "assigned_users" do
    it "should return all assigned users" do
      u1 = Factory(:user)
      u2 = Factory(:user)
      u3 = Factory(:user)
      s = Factory(:survey)
      s.generate_response! u1
      s.generate_response! u2
      #no response for user 3

      s.assigned_users.should == [u1,u2]
    end
  end
  describe "can_edit?" do
    before :each do 
      @s = Factory(:survey)
    end
    it "should allow editing if user has permission and is from survey's company" do
      u = Factory(:user,:company=>@s.company,:survey_edit=>true)
      @s.can_edit?(u).should be_true
    end
    it "should not allow editing if user doesn't have permission" do
      u = Factory(:user,:company=>@s.company)
      @s.can_edit?(u).should be_false
    end
    it "should not allow editing if user isn't from survey's company" do
      u = Factory(:user,:survey_edit=>true)
      @s.can_edit?(u).should be_false
    end
  end
  describe :rating_values do
    it "should return empty array if no values" do
      Survey.new.rating_values.should == []
    end
    it "should return values, one per line" do
      vals = "a\nb"
      Survey.new(:ratings_list=>vals).rating_values.should == ["a","b"]
    end
  end
  describe "to_xls" do
    before :each do
      @survey = Factory(:survey,:name=>"my name",:email_subject=>"emlsubj",:email_body=>"emlbod",:ratings_list=>"1\n2") 
      @q1 = Factory(:question,:rank=>1,:survey_id=>@survey.id,:content=>'my question content 1',:choices=>"x",:warning=>true)
      @q2 = Factory(:question,:rank=>2,:survey_id=>@survey.id,:content=>'my question content 2')
      
      @r1 = Factory(:survey_response, :survey_id=>@survey.id, :subtitle=>"sub", :rating=>"rat", :email_sent_date=>Time.now, :response_opened_date=>Time.now, :submitted_date=>Time.now)
      @r2 = Factory(:survey_response, :survey_id=>@survey.id, :subtitle=>"sub2", :submitted_date=>Time.now)
      @r3 = Factory(:survey_response, :survey_id=>@survey.id, :submitted_date=>nil)

      @a1 = Factory(:answer, :question_id=>@q1.id, :rating=>"1", :survey_response_id=>@r1.id)
      @a2 = Factory(:answer, :question_id=>@q2.id, :rating=>"2", :survey_response_id=>@r2.id)
      @a3 = Factory(:answer, :question_id=>@q1.id, :rating=>"2", :survey_response_id=>@r3.id)
    end

    it "should create an excel file" do
      wb = @survey.to_xls
      responses = wb.worksheet 'Survey Responses'
      responses.should_not be_nil

      responses.row_count.should == 4
      responses.row(0).should == ['Company', 'Label', 'Responder', 'Status', 'Rating', 'Invited', 'Opened', 'Submitted', 'Last Updated']
      x = responses.row(1)
      x[0].should == @r1.user.company.name
      x[1].should == @r1.subtitle
      x[2].should == @r1.user.full_name
      x[3].should == @r1.status
      x[4].should == @r1.rating
      x[5].to_s.should == @r1.email_sent_date.to_s
      x[6].to_s.should == @r1.response_opened_date.to_s
      x[7].to_s.should == @r1.submitted_date.to_s
      x[8].to_s.should == @r1.updated_at.to_s

      responses.row(2)[1].should == @r2.subtitle

      questions = wb.worksheet "Questions"
      questions.should_not be_nil

      questions.row(0).should == ["Question", "Answered", "1", "2"]
      x = questions.row(1)
      x[0].should == @q1.content
      x[1].should == 1
      x[2].should == 1
      x[3].should == 1

      x = questions.row(2)
      x[0].should == @q2.content
      x[1].should == 1
      x[2].should == 0
      x[3].should == 1
    end
  end
end
