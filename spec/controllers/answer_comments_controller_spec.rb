require 'spec_helper'

describe AnswerCommentsController do
  describe :create do
    before :each do
      @user = Factory(:user,first_name:'Joe',last_name:'Jackson')

      sign_in_as @user
      @answer = Factory(:answer) 
      allow_any_instance_of(SurveyResponse).to receive(:can_view?).and_return true
    end
    it "should check permission on parent survey response can_view?" do
      allow_any_instance_of(SurveyResponse).to receive(:can_view?).and_return false
      expect {post :create, answer_id:@answer.id.to_s}.to raise_error ActionController::RoutingError
    end
    it "should add comment and return json response" do
      allow_any_instance_of(SurveyResponse).to receive(:can_edit?).and_return true
      post :create, 'answer_id' => @answer.id.to_s, 'comment'=>{'content'=>'mytext','private'=>'true'}
      c = @answer.answer_comments.first
      expect(c.user).to eq(@user)
      expect(c.content).to eq('mytext')
      expect(c.private).to be_truthy
      expect(response).to be_success
      j = JSON.parse response.body
      expect(j['answer_comment']['user']['full_name']).to eq('Joe Jackson')
      expect(j['answer_comment']['private']).to be_truthy
      expect(j['answer_comment']['content']).to eq('mytext')
    end
    it "should create update record" do
      allow_any_instance_of(SurveyResponse).to receive(:can_edit?).and_return true
      post :create, 'answer_id' => @answer.id.to_s, 'comment'=>{'content'=>'mytext','private'=>'true'}
      expect(@answer.survey_response.survey_response_updates.first.user).to eq(@user)
    end
    it "should strip private flag if user cannot edit survey response" do
      allow_any_instance_of(SurveyResponse).to receive(:can_edit?).and_return false 
      post :create, 'answer_id' => @answer.id.to_s, 'comment'=>{'content'=>'mytext','private'=>'true'}
      c = @answer.answer_comments.first
      expect(c.private).to be_falsey
      expect(response).to be_success
      j = JSON.parse response.body
      expect(j['answer_comment']['private']).to be_falsey
    end
  end
end
