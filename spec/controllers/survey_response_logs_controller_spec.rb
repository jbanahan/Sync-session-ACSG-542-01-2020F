describe SurveyResponseLogsController do
  describe "index" do
    let(:survey_response) { create(:survey_response) }
    let!(:log) { survey_response.survey_response_logs.create!(message: "x") }

    before do
      user = create(:user)

      sign_in_as user
    end

    it 'shows logs' do
      allow_any_instance_of(SurveyResponse).to receive(:can_view?).and_return(true)
      get :index, {"survey_response_id" => survey_response.id}
      expect(response).to be_success
      expect(assigns(:logs).to_a).to eq([log])
    end

    it 'does not show logs if user cannot view survey response' do
      allow_any_instance_of(SurveyResponse).to receive(:can_view?).and_return(false)
      get :index, {"survey_response_id" => survey_response.id}
      expect(response).to redirect_to request.referer
      expect(flash[:errors]).not_to be_empty
    end
  end
end
