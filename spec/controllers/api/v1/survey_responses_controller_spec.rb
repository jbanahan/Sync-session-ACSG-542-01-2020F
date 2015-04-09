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
      s = Factory(:survey_response, subtitle: "sub", user: user, checkout_by_user: user, checkout_token: "token", checkout_expiration: Time.zone.now + 1.day)
      c = s.checkout_by_user
      allow_api_access s.user

      get :index
      expect(response).to be_success
      expect(response.body).to eq({results: [{id: s.id, name: s.survey.name, subtitle: s.subtitle, status: s.status, checkout_token: s.checkout_token, checkout_by_user: {id: c.id, username: c.username, full_name: c.full_name}, checkout_expiration: s.checkout_expiration}]}.to_json)
    end

    it "excludes checkout token if checked out by another user" do
      user = Factory(:user, survey_view: true)
      s = Factory(:survey_response, subtitle: "sub", user: user, checkout_by_user: Factory(:user), checkout_token: "token", checkout_expiration: Time.zone.now + 1.day)

      c = s.checkout_by_user
      allow_api_access s.user

      get :index
      expect(response).to be_success
      expect(response.body).to eq({results: [{id: s.id, name: s.survey.name, subtitle: s.subtitle, status: s.status, checkout_token: nil, checkout_by_user: {id: c.id, username: c.username, full_name: c.full_name}, checkout_expiration: s.checkout_expiration}]}.to_json)
    end

    it "clears checkout information if its outdated" do
      user = Factory(:user, survey_view: true)
      s = Factory(:survey_response, subtitle: "sub", user: user, checkout_by_user: Factory(:user), checkout_token: "token", checkout_expiration: Time.zone.now - 1.day)

      c = s.checkout_by_user
      allow_api_access s.user
      get :index
      expect(response).to be_success
      expect(response.body).to eq({results: [{id: s.id, name: s.survey.name, subtitle: s.subtitle, status: s.status, checkout_token: nil, checkout_by_user: nil, checkout_expiration: nil}]}.to_json)
    end
  end

  describe "show" do

    before :each do
      @user = Factory(:user, survey_view: true)
      @survey_response = Factory(:survey_response,:user=>@user)

      allow_api_access @user
    end

    it "retrieves a survey response" do
      get :show, {id: @survey_response.id}

      expect(response).to be_success
      j = JSON.parse response.body
      expect(j['survey_response']['id']).to eq @survey_response.id
    end

    it "clears expired checkout information" do
      @survey_response.checkout_token = "token"
      @survey_response.checkout_by_user = @user
      @survey_response.checkout_expiration = Time.zone.now - 1.day
      @survey_response.save!

      get :show, {id: @survey_response.id}

      expect(response).to be_success
      j = JSON.parse response.body
      expect(j['survey_response']['id']).to eq @survey_response.id
      @survey_response.reload
      expect(@survey_response.checkout_by_user).to be_nil
      expect(@survey_response.checkout_token).to be_nil
      expect(@survey_response.checkout_expiration).to be_nil
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

    context "with corrective_action_plan" do
      before :each do
        @cap = @survey_response.create_corrective_action_plan! status: CorrectiveActionPlan::STATUSES[:active]
        @comment = @cap.comments.create! body: "Comment", user: @user, created_at: (Time.zone.now - 1.day)
        @issue = @cap.corrective_issues.create! description: "Description", suggested_action: "Do this", action_taken: "Did that"
        @att = @issue.attachments.create! attached_file_name: "file.txt", attached_file_size: 1

        @req = {
          id: @survey_response.id,
          checkout_token: @survey_response.checkout_token,
          corrective_action_plan: {
            comments: [
              {id: @comment.id, body: "body"},
              {body: "Another Comment"}
            ],
            corrective_issues: [
              {id: @issue.id, action_taken: "Did something else"}
            ]
          }
        }

      end

      it "updates corrective action plan data" do
        post :checkin, {id: @survey_response.id, 'survey_response' => @req}
        expect(response).to be_success

        @cap.reload
        @issue.reload
        # Comments are ordered in desc order
        expect(@cap.comments.size).to eq 2
        expect(@cap.comments.first.body).to eq "Another Comment"
        expect(@cap.corrective_issues.size).to eq 1
        expect(@cap.corrective_issues.first.action_taken).to eq "Did something else"

        j = JSON.parse response.body
        cp = j['survey_response']['corrective_action_plan']
        first_comment = @cap.comments.first
        second_comment = @cap.comments.second
        expect(cp).to eq({
          id: @cap.id,
          status: "Active",
          can_edit: false,
          can_update_actions: true,
          comments: [
            {
              id: first_comment.id,
              body: first_comment.body,
              html_body: first_comment.html_body,
              user: {
                id: first_comment.user.id,
                username: first_comment.user.username,
                full_name: first_comment.user.full_name
              }
            },
            {
              id: second_comment.id,
              body: second_comment.body,
              html_body: second_comment.html_body,
              user: {
                id: first_comment.user.id,
                username: first_comment.user.username,
                full_name: first_comment.user.full_name
              }
            }
          ],
          corrective_issues: [
            {
              id: @issue.id,
              description: @issue.description,
              html_description: @issue.html_description,
              suggested_action: @issue.suggested_action,
              html_suggested_action: @issue.html_suggested_action,
              action_taken: @issue.action_taken,
              html_action_taken: @issue.html_action_taken,
              resolved: nil,
              attachments: [
                {
                  id: @att.id,
                  name: @att.attached_file_name,
                  type: nil,
                  size: "1 Byte"
                }
              ]
            }
          ]

        }.with_indifferent_access)

      end

      it "skips action plan data for new plans" do
        @cap.status = CorrectiveActionPlan::STATUSES[:new]
        @cap.save!

        post :checkin, {id: @survey_response.id, 'survey_response' => @req}
        expect(response).to be_success

        @cap.reload
        expect(@cap.comments.size).to eq 1
        expect(@cap.corrective_issues.first.action_taken).to eq "Did that"
      end

      it "skips action plan data for resolved plans" do
        @cap.status = CorrectiveActionPlan::STATUSES[:resolved]
        @cap.save!

        post :checkin, {id: @survey_response.id, 'survey_response' => @req}
        expect(response).to be_success

        @cap.reload
        expect(@cap.comments.size).to eq 1
        expect(@cap.corrective_issues.first.action_taken).to eq "Did that"
      end
    end
  end

  describe "submit" do
     before :each do
      @user = Factory(:user, survey_view: true)
      @survey = Factory(:survey)
      @question = Factory(:question, survey: @survey, content: "Is this a test?", choices: "Yes\nNo", rank: 0)
      @survey_response = @survey.generate_response! @user
      @survey_response.update_attributes! name: "Name", address: "123 Fake St", phone: "123-456-7890", email: "me@there.com"
      @survey_response.survey_response_logs.destroy_all
      @answer = @survey_response.answers.first
      allow_api_access @user
    end

    it "marks a response as submitted" do
      post :submit, {id: @survey_response.id}
      expect(response).to be_success
      @survey_response.reload

      j = JSON.parse response.body
      # The response should be the same as a show response...just check for an id
      expect(j['survey_response']['id']).to eq @survey_response.id

      expect(@survey_response.submitted_date.strftime "%Y-%m-%d").to eq Time.zone.now.strftime("%Y-%m-%d")
      expect(@survey_response.survey_response_logs.size).to eq 1
      expect(@survey_response.survey_response_logs.first.message).to eq "Response submitted."
      expect(@survey_response.survey_response_logs.first.user).to eq @user
      expect(@survey_response.survey_response_updates.size).to eq 1
      expect(@survey_response.survey_response_updates.first.user).to eq @user
    end

    it "validates name present" do
      @survey_response.update_attributes! name: nil
      post :submit, {id: @survey_response.id}
      expect(response.status).to eq 403
      expect(JSON.parse response.body).to eq({'errors' => ['Name, Address, Phone, and Email must all be filled in.']})
    end

    it "validates address present" do
      @survey_response.update_attributes! address: nil
      post :submit, {id: @survey_response.id}
      expect(response.status).to eq 403
      expect(JSON.parse response.body).to eq({'errors' => ['Name, Address, Phone, and Email must all be filled in.']})
    end

    it "validates phone present" do
      @survey_response.update_attributes! phone: nil
      post :submit, {id: @survey_response.id}
      expect(response.status).to eq 403
      expect(JSON.parse response.body).to eq({'errors' => ['Name, Address, Phone, and Email must all be filled in.']})
    end

    it "validates email present" do
      @survey_response.update_attributes! email: nil
      post :submit, {id: @survey_response.id}
      expect(response.status).to eq 403
      expect(JSON.parse response.body).to eq({'errors' => ['Name, Address, Phone, and Email must all be filled in.']})
    end

    it "validates not archived" do
      @survey_response.archived = true
      @survey_response.save!
      post :submit, {id: @survey_response.id}
      expect(response.status).to eq 403
      expect(JSON.parse response.body).to eq({'errors' => ["Archived surveys cannot be submitted."]})
    end

    it "validates not rated" do
      @survey_response.rating = "Rated"
      @survey_response.save!
      post :submit, {id: @survey_response.id}
      expect(response.status).to eq 403
      expect(JSON.parse response.body).to eq({'errors' => ["Rated surveys cannot be submitted."]})
    end

    it "validates not expired" do
      @survey_response.expiration_notification_sent_at = (Time.zone.now - 1.minute)
      @survey_response.save!
      post :submit, {id: @survey_response.id}
      expect(response.status).to eq 403
      expect(JSON.parse response.body).to eq({'errors' => ["Expired surveys cannot be submitted."]})
    end

    it "validates not checked out" do
      @survey_response.checkout_token = "token"
      @survey_response.save!
      post :submit, {id: @survey_response.id}
      expect(response.status).to eq 403
      expect(JSON.parse response.body).to eq({'errors' => ["Checked out surveys cannot be submitted."]})
    end

    it "validates not submitted" do
      @survey_response.submitted_date = Time.zone.now
      @survey_response.save!
      post :submit, {id: @survey_response.id}
      expect(response.status).to eq 403
      expect(JSON.parse response.body).to eq({'errors' => ["Submitted surveys cannot be submitted."]})
    end

    context "without locked questions" do
      before :each do
        Survey.any_instance.stub(:locked?).and_return false
      end

      it "validates required questions are answered" do
        @question.warning = true
        @question.save!
        post :submit, {id: @survey_response.id}
        expect(response.status).to eq 403
        expect(JSON.parse response.body).to eq({'errors' => ["Question #1 is a required question. You must provide an answer."]})
      end

      it "validates required questions have comments" do
        @question.warning = true
        @question.choices = nil
        @question.save!
        post :submit, {id: @survey_response.id}
        expect(response.status).to eq 403
        expect(JSON.parse response.body).to eq({'errors' => ["Question #1 is a required question. You must provide a comment."]})
      end

      it "validates questions marked as requiring comments have them" do
        @question.require_comment = true
        @question.save!
        @answer.update_attributes! choice: "Yes"
        post :submit, {id: @survey_response.id}
        expect(response.status).to eq 403
        expect(JSON.parse response.body).to eq({'errors' => ["Question #1 is a required question. You must provide a comment."]})
      end

      it "validates questions marked as requiring comments have them, ignoring comments by non-survey takers" do
        @question.require_comment = true
        @question.save!
        @answer.update_attributes! choice: "Yes"
         @answer.answer_comments.create! content: "Comment", user: Factory(:user)
        post :submit, {id: @survey_response.id}
        expect(response.status).to eq 403
        expect(JSON.parse response.body).to eq({'errors' => ["Question #1 is a required question. You must provide a comment."]})
      end

      it "validates does not error if questions requiring comments have comments" do
        @question.require_comment = true
        @question.save!
        @answer.update_attributes! choice: "Yes"
        @answer.answer_comments.create! content: "Comment", user: @user
        post :submit, {id: @survey_response.id}
        expect(response).to be_success
      end

      it "validates questions marked as requiring comments for a specific choice have them" do
        @question.comment_required_for_choices = "Yes"
        @question.save!
        @answer.update_attributes! choice: "Yes"
        post :submit, {id: @survey_response.id}
        expect(response.status).to eq 403
        expect(JSON.parse response.body).to eq({'errors' => ["Question #1 is a required question. You must provide a comment."]})
      end

      it "validates questions marked as requiring comments for a specific choice doesn't fail if choice is not in list" do
        @question.comment_required_for_choices = "No"
        @question.save!
        @answer.update_attributes! choice: "Yes"
        post :submit, {id: @survey_response.id}
        expect(response).to be_success
      end

      it "validates questions marked as requiring attachments have them" do
        @question.require_attachment = true
        @question.save!
        @answer.update_attributes! choice: "Yes"
        post :submit, {id: @survey_response.id}
        expect(response.status).to eq 403
        expect(JSON.parse response.body).to eq({'errors' => ["Question #1 is a required question. You must provide an attachment."]})
      end

      it "validates questions marked as requiring attachments have them, ignoring attachments by non-survey takers" do
        @question.require_attachment = true
        @question.save!
        @answer.update_attributes! choice: "Yes"
        @answer.attachments.create! attached_file_name: "file.text", uploaded_by: Factory(:user)
        post :submit, {id: @survey_response.id}
        expect(response.status).to eq 403
        expect(JSON.parse response.body).to eq({'errors' => ["Question #1 is a required question. You must provide an attachment."]})
      end

      it "validates does not error if questions requiring attachments have comments" do
        @question.warning = true
        @question.require_attachment = true
        @question.save!
        @answer.update_attributes! choice: "Yes"
        @answer.attachments.create! attached_file_name: "file.text", uploaded_by: @user
        post :submit, {id: @survey_response.id}
        expect(response).to be_success
      end

      it "validates questions marked as requiring comments for a specific choice have them" do
        @question.warning = true
        @question.attachment_required_for_choices = "Yes"
        @question.save!
        @answer.update_attributes! choice: "Yes"
        post :submit, {id: @survey_response.id}
        expect(response.status).to eq 403
        expect(JSON.parse response.body).to eq({'errors' => ["Question #1 is a required question. You must provide an attachment."]})
      end

      it "validates questions marked as requiring attachments for a specific choice doesn't fail if choice is not in list" do
        @question.attachment_required_for_choices = "No"
        @question.save!
        @answer.update_attributes! choice: "Yes"
        post :submit, {id: @survey_response.id}
        expect(response).to be_success
      end
    end
    
  end
end