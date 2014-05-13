require 'spec_helper'

describe AnswerCommentsController do
  describe :create do
    before :each do
      @user = Factory(:user,first_name:'Joe',last_name:'Jackson')

      sign_in_as @user
      @answer = Factory(:answer) 
      SurveyResponse.any_instance.stub(:can_view?).and_return true
    end
    it "should check permission on parent survey response can_view?" do
      SurveyResponse.any_instance.stub(:can_view?).and_return false
      lambda {post :create, answer_id:@answer.id.to_s}.should raise_error ActionController::RoutingError
    end
    it "should add comment and return json response" do
      SurveyResponse.any_instance.stub(:can_edit?).and_return true
      post :create, 'answer_id' => @answer.id.to_s, 'comment'=>{'content'=>'mytext','private'=>'true'}
      c = @answer.answer_comments.first
      c.user.should == @user
      c.content.should == 'mytext'
      c.private.should be_true
      response.should be_success
      j = JSON.parse response.body
      j['answer_comment']['user']['full_name'].should == 'Joe Jackson'
      j['answer_comment']['private'].should be_true
      j['answer_comment']['content'].should == 'mytext'
    end
    it "should create update record" do
      SurveyResponse.any_instance.stub(:can_edit?).and_return true
      post :create, 'answer_id' => @answer.id.to_s, 'comment'=>{'content'=>'mytext','private'=>'true'}
      @answer.survey_response.survey_response_updates.first.user.should == @user
    end
    it "should strip private flag if user cannot edit survey response" do
      SurveyResponse.any_instance.stub(:can_edit?).and_return false 
      post :create, 'answer_id' => @answer.id.to_s, 'comment'=>{'content'=>'mytext','private'=>'true'}
      c = @answer.answer_comments.first
      c.private.should be_false
      response.should be_success
      j = JSON.parse response.body
      j['answer_comment']['private'].should be_false
    end
  end
end
