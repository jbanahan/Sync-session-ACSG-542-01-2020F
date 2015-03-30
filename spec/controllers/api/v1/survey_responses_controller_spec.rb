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
      # expecting to modify is in the rendered result and the survey_response
      expect(j['survey_response']['checkout_token']).to eq "token"
      expect(Time.zone.parse(j['survey_response']['checkout_expiration'][0, 11])).to eq 2.days.from_now.strftime("%Y%m%d")
      expect(j['survey_response']['checkout_by_user']).to eq({id: @user.id, username: @user.username, full_name: @user.full_name}.with_indifferent_access)

      @survey_response.reload
      expect(@survey_response.checkout_by_user).to eq @user
      expect(@survey_response.checkout_token).to eq "token"
      expect(@survey_response.checkout_expiration.strftime("%Y%m%d")).to eq 2.days.from_now.strftime("%Y%m%d")
      expect(@survey_response.survey_response_logs.first.message).to eq "Checked out."
      expect(@survey_response.survey_response_logs.first.user).to eq @user
    end

    it "fails if survey is already checked out" do
      @survey_response.checkout_by_user = Factory(:user)
      @survey_response.save!

      post :checkout, {id: @survey_response.id, checkout_token: "token"}

      expect(response.status).to eq 403
      expect(JSON.parse response.body).to eq({'errors' => ['Survey is checked out by another user.']})
    end

    it "fails if survey is checked out to user on another device/token" do
      @survey_response.checkout_by_user = @user
      @survey_response.checkout_token = "differentoken"
      @survey_response.save!

      post :checkout, {id: @survey_response.id, checkout_token: "token"}

      expect(response.status).to eq 403
      expect(JSON.parse response.body).to eq({'errors' => ["Survey is checked out to you on another device."]})
    end

    it 'errors if checkout token is not sent' do
      post :checkout, {id: @survey_response.id}

      expect(response.status).to eq 500
      expect(JSON.parse response.body).to eq({'errors' => ["No checkout_token received."]})
    end

    it "fails if survey is archived" do
      @survey_response.archived = true
      @survey_response.save!

      post :checkout, {id: @survey_response.id, checkout_token: "token"}

      expect(response.status).to eq 403
      expect(JSON.parse response.body).to eq({'errors' => ['Survey is archived.']})
    end

    it "fails if survey is archived" do
      @survey_response.survey.archived = true
      @survey_response.survey.save!

      post :checkout, {id: @survey_response.id, checkout_token: "token"}

      expect(response.status).to eq 403
      expect(JSON.parse response.body).to eq({'errors' => ['Survey is archived.']})
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
      # expecting to modify is in the rendered result and the survey_response
      expect(j['survey_response']['checkout_token']).to be_nil
      expect(j['survey_response']['checkout_expiration']).to be_nil
      expect(j['survey_response']['checkout_by_user']).to be_nil

      @survey_response.reload
      expect(@survey_response.checkout_by_user).to be_nil
      expect(@survey_response.checkout_token).to be_nil
      expect(@survey_response.checkout_expiration).to be_nil

      expect(@survey_response.survey_response_logs.first.message).to eq "Check out cancelled."
      expect(@survey_response.survey_response_logs.first.user).to eq @user
    end

    it "fails if user doesn't own the checkout" do
      @survey_response.checkout_by_user = Factory(:user)
      @survey_response.save!

      post :cancel_checkout, {id: @survey_response.id, checkout_token: "token"}

      expect(response.status).to eq 403
      expect(JSON.parse response.body).to eq({'errors' => ['Survey is checked out by another user.']})
    end

    it "fails if another device owns the checkout" do
      post :cancel_checkout, {id: @survey_response.id, checkout_token: "token2"}

      expect(response.status).to eq 403
      expect(JSON.parse response.body).to eq({'errors' => ["Survey is checked out to you on another device."]})
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

    it "fails if survey is archived" do
      @survey_response.archived = true
      @survey_response.save!

      post :cancel_checkout, {id: @survey_response.id, checkout_token: "token"}

      expect(response.status).to eq 403
      expect(JSON.parse response.body).to eq({'errors' => ['Survey is archived.']})
    end

    it "fails if survey is archived" do
      @survey_response.survey.archived = true
      @survey_response.survey.save!

      post :cancel_checkout, {id: @survey_response.id, checkout_token: "token"}

      expect(response.status).to eq 403
      expect(JSON.parse response.body).to eq({'errors' => ['Survey is archived.']})
    end
  end

  describe :checkin do

    before :each do
      @user = Factory(:user, survey_view: true)
      @survey = Factory(:survey)
      @question = Factory(:question, survey: @survey, content: "Is this a test?", choices: "Yes\nNo")
      @survey_response = Factory(:survey_response, survey: @survey, user: @user, checkout_by_user: @user, checkout_token: "token", checkout_expiration: Time.zone.now)
      
      allow_api_access @user

      @req = {
        id: @survey_response.id,
        checkout_token: @survey_response.checkout_token,
        name: "Mr. Survey Taker",
        address: "123 Fake St.\nAnywhere, PA, 01234",
        phone: "123-456-7890",
        email: "me@there.com",
        fax: "098-765-4321",
        answers: [
          {
            choice: "Yes",
            question_id: @question.id,
            answer_comments: [
              {
                content: "This is a comment."
              }
            ]
          }
        ]
      }
    end


    it "checks in a survey" do
      post :checkin, {'id' => @survey_response.id, 'survey_response' => @req}
      expect(response).to be_success
      
      @survey_response.reload

      expect(@survey_response.name).to eq @req[:name]
      expect(@survey_response.address).to eq @req[:address]
      expect(@survey_response.phone).to eq @req[:phone]
      expect(@survey_response.address).to eq @req[:address]
      expect(@survey_response.email).to eq @req[:email]
      expect(@survey_response.fax).to eq @req[:fax]
      expect(@survey_response.checkout_by_user).to be_nil
      expect(@survey_response.checkout_token).to be_nil
      expect(@survey_response.checkout_expiration).to be_nil

      expect(@survey_response.answers.size).to eq 1

      a = @survey_response.answers.first
      expect(a.choice).to eq "Yes"
      expect(a.question).to eq @question
      expect(a.answer_comments.size).to eq 1

      expect(a.answer_comments.first.content).to eq "This is a comment."
      expect(a.answer_comments.first.user).to eq @user

      expect(@survey_response.survey_response_logs.first.message).to eq "Checked in."
      expect(@survey_response.survey_response_logs.first.user).to eq @user
      expect(@survey_response.survey_response_updates.first.user).to eq @user
    end

    it "updates existing answers" do
      answer = @survey_response.answers.create! question: @question, choice: "No"
      @req[:answers].first[:id] = answer.id

      post :checkin, {'id' => @survey_response.id, 'survey_response' => @req}
      expect(response).to be_success
      
      @survey_response.reload

      expect(@survey_response.answers.size).to eq 1
      a = @survey_response.answers.first
      expect(a.choice).to eq "Yes"
      expect(a.answer_comments.size).to eq 1
      expect(a.answer_comments.first.content).to eq "This is a comment."
    end

    it "errors if survey checkout has expired" do
      @survey_response.checkout_by_user = nil
      @survey_response.checkout_token = nil
      @survey_response.checkout_expiration = nil
      @survey_response.save!

      post :checkin, {'id' => @survey_response.id, 'survey_response' => @req}
      expect(response.status).to eq 403
      expect(JSON.parse response.body).to eq({'errors' => ["The survey checkout has expired.  Check out the survey again before checking it back in."]})
    end

    it "skips updating existing answer comments" do
      answer = @survey_response.answers.create! question: @question, choice: "No"
      comment = answer.answer_comments.create! content: "Comment", user: @user

      @req[:answers].first[:id] = answer.id
      @req[:answers].first[:answer_comments].first[:id] = answer.id

      post :checkin, {'id' => @survey_response.id, 'survey_response' => @req}
      expect(response).to be_success
      
      @survey_response.reload
      expect(@survey_response.answers.size).to eq 1
      a = @survey_response.answers.first
      expect(a.choice).to eq "Yes"
      expect(a.answer_comments.size).to eq 1
      # Validate the original data is present, and wasn't updated to what was in the request
      expect(a.answer_comments.first.content).to eq "Comment"
    end

    it "errors if bad question is attempted to be answered" do
      @req[:answers].first[:question_id] = -1
      post :checkin, {'id' => @survey_response.id, 'survey_response' => @req}
      expect(response.status).to eq 500
      expect(JSON.parse response.body).to eq({'errors' => ["Invalid Question responded to."]})
    end

    it "errors if invalid answer is provided" do
      # The idea here is that we don't want to allow someone to send a choice that isn't
      # specified by the question
      @req[:answers].first[:choice] = "I don't know"
      post :checkin, {'id' => @survey_response.id, 'survey_response' => @req}
      expect(response.status).to eq 500
      expect(JSON.parse response.body).to eq({'errors' => ["Invalid Answer of 'I don't know' given for question id #{@question.id}."]})
    end

    it "errors if attempting to update a non-existent answer" do 
      @req[:answers].first[:id] = -1
      post :checkin, {'id' => @survey_response.id, 'survey_response' => @req}
      expect(response.status).to eq 500
      expect(JSON.parse response.body).to eq({'errors' => ["Attempted to update an answer that does not exist."]})
    end

    it "errors if survey is not checked out to user" do
      @survey_response.checkout_by_user = Factory(:user)
      @survey_response.save!

      post :checkin, {'id' => @survey_response.id, 'survey_response' => @req}
      expect(response.status).to eq 403
      expect(JSON.parse response.body).to eq({'errors' => ["Survey is checked out by another user."]})
    end

    it "errors if survey is checked out on another device" do
      @req[:checkout_token] = "New token"

      post :checkin, {'id' => @survey_response.id, 'survey_response' => @req}
      expect(response.status).to eq 403
      expect(JSON.parse response.body).to eq({'errors' => ["Survey is checked out to you on another device."]})
    end

    it "errors if checkout token is blank" do
      @req[:checkout_token] = ""
      post :checkin, {'id' => @survey_response.id, 'survey_response' => @req}
      expect(response.status).to eq 500
      expect(JSON.parse response.body).to eq({'errors' => ["No checkout_token received."]})
    end

    it "fails if survey is archived" do
      @survey_response.archived = true
      @survey_response.save!

      post :checkin, {id: @survey_response.id, 'survey_response' => @req}

      expect(response.status).to eq 403
      expect(JSON.parse response.body).to eq({'errors' => ['Survey is archived.']})
    end

    it "fails if survey is archived" do
      @survey_response.survey.archived = true
      @survey_response.survey.save!

      post :checkin, {id: @survey_response.id, 'survey_response' => @req}

      expect(response.status).to eq 403
      expect(JSON.parse response.body).to eq({'errors' => ['Survey is archived.']})
    end
  end
end