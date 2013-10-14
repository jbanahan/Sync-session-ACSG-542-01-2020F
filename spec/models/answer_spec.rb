require 'spec_helper'

describe Answer do
  describe :can_attach? do
    before :each do
      @a = Answer.new 
      @u = User.new
    end
    it "should allow if user can view" do
      @a.should_receive(:can_view?).with(@u).and_return true
      @a.can_attach?(@u).should be_true
    end
    it "should not allow if user cannot view" do
      @a.should_receive(:can_view?).with(@u).and_return false
      @a.can_attach?(@u).should be_false
    end
  end
  describe :answered? do
    it 'should not be answered as default' do
      Factory(:answer).should_not be_answered
    end
    it 'should be answered if choice is set' do
      Factory(:answer,:choice=>'x').should be_answered
    end
    it 'should be answered if comment assigned to survey response user is set' do
      a = Factory(:answer)
      a.answer_comments.create!(:user_id=>a.survey_response.user_id,:content=>'1234567890')
      a.should be_answered
    end
    it 'should be answered if attachment assigned to survey response user is set' do
      a = Factory(:answer)
      a.attachments.create!(:uploaded_by_id=>a.survey_response.user_id)
      a.should be_answered
    end
    it 'should not be answered if only comment is from a different user' do
      a = Factory(:answer)
      a.answer_comments.create!(:user_id=>Factory(:user).id,:content=>'1234567890')
      a.should_not be_answered
    end
    it 'should not be answered if only attachment is from a different user' do
      a = Factory(:answer)
      a.attachments.create!(:uploaded_by_id=>Factory(:user).id)
      a.should_not be_answered
    end
  end
  describe "can view" do
    before :each do
      @answer = Factory(:answer)
      @u = Factory(:user)
    end
    it "should pass if user can view survey response" do
      @answer.survey_response.should_receive(:can_view?).with(@u).and_return(true)
      @answer.can_view?(@u).should be_true
    end
    it "should fail if user cannot view survey response" do
      @answer.survey_response.should_receive(:can_view?).with(@u).and_return(false)
      @answer.can_view?(@u).should be_false
    end
  end
  it "should require survey_response" do
    a = Answer.new(:question=>Factory(:question))
    a.save.should be_false
  end
  it "should require question" do
    a = Answer.new(:survey_response=>Factory(:survey_response))
    a.save.should be_false
  end
  it "should accept nested attributes for comments" do
    a = Factory(:answer)
    u = Factory(:user)
    a.update_attributes(:answer_comments_attributes=>[{:user_id=>u.id,:content=>'abcdef'}])
    AnswerComment.find_by_answer_id_and_user_id(a.id,u.id).content.should == "abcdef"
  end
  it "should not accepted updates for comments via nested attributes" do
    a = Factory(:answer)
    u = Factory(:user)
    ac = a.answer_comments.create!(:user=>u,:content=>'abcdefg')
    a.update_attributes(:answer_comments_attributes=>[{:id=>ac.id,:content=>'xxx'}])
    AnswerComment.find_by_answer_id_and_user_id(a.id,u.id).content.should == "abcdefg"
  end
  it "should allow attachments" do
    a = Factory(:answer)
    a.attachments.create!(:attached_file_name=>"x.png")
  end
  it "should update parent response when answer is updated" do
    a = Factory(:answer)
    a.survey_response.update_attributes(:updated_at=>1.week.ago)
    a.choice = "X"
    a.save!
    SurveyResponse.find(a.survey_response_id).updated_at.should > 1.second.ago
  end
end
