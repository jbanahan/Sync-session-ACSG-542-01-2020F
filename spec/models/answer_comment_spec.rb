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
end
