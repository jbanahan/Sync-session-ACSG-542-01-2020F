describe SurveyResponseLogsController do
  describe "index" do
    before :each do
      u = Factory(:user)

      sign_in_as u
      @sr = Factory(:survey_response)
      @log = @sr.survey_response_logs.create!(:message=>"x")
    end
    it 'should show logs' do
      allow_any_instance_of(SurveyResponse).to receive(:can_view?).and_return(true)
      get :index, {"survey_response_id"=>@sr.id}
      expect(response).to be_success
      expect(assigns(:logs).to_a).to eq([@log])
    end
    it 'should not show logs if user cannot view survey response' do
      allow_any_instance_of(SurveyResponse).to receive(:can_view?).and_return(false)
      get :index, {"survey_response_id"=>@sr.id}
      expect(response).to redirect_to request.referrer
      expect(flash[:errors]).not_to be_empty
    end
  end
end
