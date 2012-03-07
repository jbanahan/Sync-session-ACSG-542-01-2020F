require 'spec_helper'

describe SurveyResponsesController do
  before :each do
    activate_authlogic
    @u = Factory(:user)
    UserSession.create! @u
  end
  describe 'show' do
    it 'should redirect to show_responder if current_user == survey_response.user' do
      sr = Factory(:survey_response,:user=>@u)
      get :show, :id=>sr.id
      assigns(:sr).should == sr
      assigns(:rate_mode).should be_false
      assigns(:respond_mode).should be_true
    end
    it 'should redirect to show_rater if current_user.edit_surveys? && current_user.company == survey_response.survey.company' do
      @u.update_attributes(:survey_edit=>true)
      sr = Factory(:survey_response,:survey=>Factory(:survey,:company=>@u.company))
      get :show, :id=>sr.id
      assigns(:sr).should == sr
      assigns(:rate_mode).should be_true
      assigns(:respond_mode).should be_false
    end
    it "should not display if it doesn't pass the other tests" do
      sr = Factory(:survey_response)
      get :show, :id=>sr.id
      response.should redirect_to root_path
      flash[:errors].count.should == 1
    end
  end
  describe 'index' do
    it 'should only show survey responses assigned to current_user' do
      to_find = Factory(:survey_response,:user=>@u)
      dont_find = Factory(:survey_response)
      get :index
      response.should be_success
      assigns(:survey_responses).to_a.should == [to_find]
    end
  end
end
