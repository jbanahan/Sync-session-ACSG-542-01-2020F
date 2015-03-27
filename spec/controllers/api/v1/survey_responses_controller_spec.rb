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

      expect(j).to eq({results: [{id: s.id, name: s.survey.name, subtitle: s.subtitle, status: s.status, checkout_token: nil, checkout_by_user: nil, checkout_expiration: nil}]}.with_indifferent_access)
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

      expect(j).to eq({results: [{id: s.id, name: s.survey.name, subtitle: s.subtitle, status: s.status, checkout_token: nil, checkout_by_user: nil, checkout_expiration: nil}]}.with_indifferent_access)
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

    it "includes checkout information" do
      user = Factory(:user, survey_view: true)
      s = Factory(:survey_response, subtitle: "sub", user: user, checkout_by_user: user, checkout_token: "token", checkout_expiration: Time.zone.now)
      c = s.checkout_by_user
      allow_api_access s.user

      get :index
      expect(response).to be_success
      expect(response.body).to eq({results: [{id: s.id, name: s.survey.name, subtitle: s.subtitle, status: s.status, checkout_token: s.checkout_token, checkout_by_user: {id: c.id, username: c.username, full_name: c.full_name}, checkout_expiration: s.checkout_expiration}]}.to_json)
    end

    it "excludes checkout token if checked out by another user" do
      user = Factory(:user, survey_view: true)
      s = Factory(:survey_response, subtitle: "sub", user: user, checkout_by_user: Factory(:user), checkout_token: "token", checkout_expiration: Time.zone.now)

      c = s.checkout_by_user
      allow_api_access s.user

      get :index
      expect(response).to be_success
      expect(response.body).to eq({results: [{id: s.id, name: s.survey.name, subtitle: s.subtitle, status: s.status, checkout_token: nil, checkout_by_user: {id: c.id, username: c.username, full_name: c.full_name}, checkout_expiration: s.checkout_expiration}]}.to_json)
    end
  end

  describe "checkout" do
    before :each do
      @user = Factory(:user, survey_view: true)
      @survey_response = Factory(:survey_response,:user=>@user)

      allow_api_access @user
    end

    it "checks out a survey to a user" do
      post :checkout, {id: @survey_response.id, checkout_token: "token"}

      expect(response).to be_success
      j = JSON.parse response.body

      # This method calls the same renderer as show, just test that some of the data we're
      # expecting to modify is in the rendered result and the survey_resposne
      expect(j['survey_response']['checkout_token']).to eq "token"
      expect(Time.zone.parse(j['survey_response']['checkout_expiration'][0, 11])).to eq 2.days.from_now.strftime("%Y%m%d")
      expect(j['survey_response']['checkout_by_user']).to eq({id: @user.id, username: @user.username, full_name: @user.full_name}.with_indifferent_access)

      @survey_response.reload
      expect(@survey_response.checkout_by_user).to eq @user
      expect(@survey_response.checkout_token).to eq "token"
      expect(@survey_response.checkout_expiration.strftime("%Y%m%d")).to eq 2.days.from_now.strftime("%Y%m%d")
    end

    it "fails if survey is already checked out" do
      @survey_response.checkout_by_user = Factory(:user)
      @survey_response.save!

      post :checkout, {id: @survey_response.id, checkout_token: "token"}

      expect(response.status).to eq 403
      expect(JSON.parse response.body).to eq({'errors' => ['Survey is already checked out by another user.']})
    end

    it "fails if survey is checked out to user on another device/token" do
      @survey_response.checkout_by_user = @user
      @survey_response.checkout_token = "differentoken"
      @survey_response.save!

      post :checkout, {id: @survey_response.id, checkout_token: "token"}

      expect(response.status).to eq 403
      expect(JSON.parse response.body).to eq({'errors' => ["Survey is already checked out to you on another device."]})
    end

    it 'errors if checkout token is not sent' do
      post :checkout, {id: @survey_response.id}

      expect(response.status).to eq 500
      expect(JSON.parse response.body).to eq({'errors' => ["No checkout_token received."]})
    end
  end

  describe "cancel_checkout" do
    before :each do
      @user = Factory(:user, survey_view: true)
      @survey_response = Factory(:survey_response, user: @user, checkout_by_user: @user, checkout_token: "token", checkout_expiration: Time.zone.now)

      allow_api_access @user
    end

    it "removes checkout info from survey response" do
      post :cancel_checkout, {id: @survey_response.id, checkout_token: "token"}

      expect(response).to be_success
      j = JSON.parse response.body

      # This method calls the same renderer as show, just test that some of the data we're
      # expecting to modify is in the rendered result and the survey_resposne
      expect(j['survey_response']['checkout_token']).to be_nil
      expect(j['survey_response']['checkout_expiration']).to be_nil
      expect(j['survey_response']['checkout_by_user']).to be_nil

      @survey_response.reload
      expect(@survey_response.checkout_by_user).to be_nil
      expect(@survey_response.checkout_token).to be_nil
      expect(@survey_response.checkout_expiration).to be_nil
    end

    it "fails if user doesn't own the checkout" do
      @survey_response.checkout_by_user = Factory(:user)
      @survey_response.save!

      post :cancel_checkout, {id: @survey_response.id, checkout_token: "token"}

      expect(response.status).to eq 403
      expect(JSON.parse response.body).to eq({'errors' => ['Survey is already checked out by another user.']})
    end

    it "fails if another device owns the checkout" do
      post :cancel_checkout, {id: @survey_response.id, checkout_token: "token2"}

      expect(response.status).to eq 403
      expect(JSON.parse response.body).to eq({'errors' => ["Survey is already checked out to you on another device."]})
    end

    it "fails if checkout token is missing" do
      post :cancel_checkout, {id: @survey_response.id}

      expect(response.status).to eq 500
      expect(JSON.parse response.body).to eq({'errors' => ["No checkout_token received."]})
    end

    it "fails if user doesn't have access to survey" do
      SurveyResponse.any_instance.should_receive(:assigned_to_user?).and_return false

      post :cancel_checkout, {id: @survey_response.id, checkout_token: "token"}

      expect(response.status).to eq 403
      expect(JSON.parse response.body).to eq({'errors' => ['Access denied.']})
    end
  end
end