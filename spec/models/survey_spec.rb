require 'spec_helper'

describe Survey do
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
end
