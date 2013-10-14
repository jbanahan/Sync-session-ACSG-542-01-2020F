require 'spec_helper'

describe AnswersController do
  describe 'update' do
    before :each do
      @u = Factory(:user)
      activate_authlogic
      UserSession.create! @u
      @answer = Factory(:answer)
    end
    it 'should allow survey user to save choice' do
      @answer.survey_response.user = @u
      @answer.survey_response.save!
      put :update, id: @answer.id, answer:{choice:'abc'}, format: :json
      response.should be_success
      @answer.reload
      @answer.choice.should == 'abc'
    end
    it 'should allow can_edit? user to save rating' do
      SurveyResponse.any_instance.stub(:can_edit?).and_return true
      put :update, id: @answer.id, answer:{rating:'abc'}, format: :json
      response.should be_success
      @answer.reload
      @answer.rating.should == 'abc'
    end
    it "should not change choice if user is not the assigned user" do
      @answer.update_attributes(choice:'def')
      SurveyResponse.any_instance.stub(:can_edit?).and_return true
      put :update, id: @answer.id, answer:{choice:'abc'}, format: :json
      response.should be_success
      @answer.reload
      @answer.choice.should == 'def'
    end
    it "should not allow rating to change if user is not able to edit" do
      @answer.update_attributes(rating:'def')
      @answer.survey_response.update_attributes(user_id:@u.id)
      SurveyResponse.any_instance.stub(:can_edit?).and_return false 
      put :update, id: @answer.id, answer:{rating:'abc'}, format: :json
      response.should be_success
      @answer.reload
      @answer.rating.should == 'def'
    end
    it "should 404 if user cannot view survey" do
      lambda {put :update, id: @answer.id, answer:{rating:'abc'}, format: :json}.should raise_error ActionController::RoutingError
    end
  end
end
