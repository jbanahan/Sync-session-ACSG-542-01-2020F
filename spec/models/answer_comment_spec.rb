require 'spec_helper'

describe AnswerComment do
  it "should require answer" do
    c = AnswerComment.new(:user=>Factory(:user),:content=>'abc')
    c.save.should be_false
  end
  it "should require user" do
    AnswerComment.new(:answer=>Factory(:answer),:content=>'abc').save.should be_false
  end
  it "should require content" do
    AnswerComment.new(:user=>Factory(:user),:answer=>Factory(:answer)).save.should be_false
  end
  it "should save with all requirements" do
    AnswerComment.new(:user=>Factory(:user),:answer=>Factory(:answer),:content=>'abc').save.should be_true
  end
  it "should update answer and response updated_at" do
    a = Factory(:answer)
    ac = a.answer_comments.create!(:user=>Factory(:user),:content=>'1239014')
    a.update_attributes(:updated_at=>1.week.ago)
    a.survey_response.update_attributes(:updated_at=>1.week.ago)
    ac.content = '191985'
    ac.save!
    a.reload
    a.updated_at.should > 1.second.ago
    a.survey_response.updated_at.should > 1.second.ago
  end
end
