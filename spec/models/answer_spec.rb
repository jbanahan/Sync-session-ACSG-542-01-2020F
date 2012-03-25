require 'spec_helper'

describe Answer do
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
end
