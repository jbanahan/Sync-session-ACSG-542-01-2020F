require 'spec_helper'

describe SurveyResponseLogsController do
  describe :index do
    before :each do 
      u = Factory(:user)
      activate_authlogic
      UserSession.create! u
      @sr = Factory(:survey_response)
      @log = @sr.survey_response_logs.create!(:message=>"x")
    end
    it 'should show logs' do
      SurveyResponse.any_instance.stub(:can_view?).and_return(true)
      get :index, {"survey_response_id"=>@sr.id}
      response.should be_success
      assigns(:logs).to_a.should == [@log]
    end
    it 'should not show logs if user cannot view survey response' do
      SurveyResponse.any_instance.stub(:can_view?).and_return(false)
      get :index, {"survey_response_id"=>@sr.id}
      response.should redirect_to request.referrer
      flash[:errors].should_not be_empty
    end
  end
end
