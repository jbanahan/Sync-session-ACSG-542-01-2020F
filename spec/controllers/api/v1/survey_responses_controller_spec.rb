require 'spec_helper'

describe Api::V1::SurveyResponsesController do

  describe "index" do
    it "returns a list of surveys accessible to the user" do
      s = Factory(:survey_response, subtitle: "sub")
      s2 = Factory(:survey_response)
      allow_api_access s.user
      s.user.update_attributes! survey_view: true

      get :index
      expect(response).to be_success
      j = JSON.parse response.body

      expect(j).to eq({results: [{id: s.id, name: s.survey.name, subtitle: s.subtitle, status: s.status, checkout_token: nil, checkout_to_user: nil, checkout_expiration: nil}]}.with_indifferent_access)
    end

    it "returns list of surveys assign to a user's group" do
      s = Factory(:survey_response, subtitle: "sub")
      g = Group.create! system_code: "Group"
      s.update_attributes! user: nil, group: g

      user = Factory(:user, survey_view: true)

      user.groups << g

      allow_api_access user

      get :index
      expect(response).to be_success
      j = JSON.parse response.body

      expect(j).to eq({results: [{id: s.id, name: s.survey.name, subtitle: s.subtitle, status: s.status, checkout_token: nil, checkout_to_user: nil, checkout_expiration: nil}]}.with_indifferent_access)
    end

    it "returns forbidden if user doesn't have survey visibility" do
      user = Factory(:user, survey_view: false)
      allow_api_access user
      get :index
      expect(response.status).to eq 403
    end

    it "does not return archived survey repsonses" do
      s = Factory(:survey_response, subtitle: "sub", archived: true)
      allow_api_access s.user
      s.user.update_attributes! survey_view: true

      get :index
      expect(response).to be_success
      j = JSON.parse response.body
      expect(j).to eq({results: []}.with_indifferent_access)
    end

    it "does not return responses linked to archived surveys" do
      s = Factory(:survey_response, subtitle: "sub")
      s.survey.update_attributes! archived: true
      allow_api_access s.user
      s.user.update_attributes! survey_view: true

      get :index
      expect(response).to be_success
      j = JSON.parse response.body
      expect(j).to eq({results: []}.with_indifferent_access)
    end
  end
end