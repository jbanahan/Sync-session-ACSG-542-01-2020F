describe SurveyResponsesController do
  describe 'show' do
    before :each do

      @u = create(:user)
      sign_in_as @u
    end
    it 'should be respond mode if current_user == survey_response.user and not submitted' do
      sr = create(:survey_response, :user=>@u)
      get :show, :id=>sr.id
      expect(assigns(:sr)).to eq(sr)
      expect(assigns(:rate_mode)).to be_falsey
      expect(assigns(:respond_mode)).to be_truthy
    end
    it 'should be respond mode if current_user is in survey group and not submitted' do
      group = create(:group)
      @u.groups << group
      sr = create(:survey_response, group: group)

      get :show, :id=>sr.id
      expect(assigns(:sr)).to eq(sr)
      expect(assigns(:rate_mode)).to be_falsey
      expect(assigns(:respond_mode)).to be_truthy
    end
    it 'should not be respond mode if submitted' do
      sr = create(:survey_response, :user=>@u, :submitted_date=>1.day.ago)
      get :show, :id=>sr.id
      expect(assigns(:sr)).to eq(sr)
      expect(assigns(:rate_mode)).to be_falsey
      expect(assigns(:respond_mode)).to be_falsey
    end
    it 'should be rate mode if current_user.edit_surveys? && current_user.company == survey_response.survey.company and survey_response.submitted_date' do
      @u.update_attributes(:survey_edit=>true)
      sr = create(:survey_response, :survey=>create(:survey, :company=>@u.company), :submitted_date=>1.day.ago)
      get :show, :id=>sr.id
      expect(assigns(:sr)).to eq(sr)
      expect(assigns(:rate_mode)).to be_truthy
      expect(assigns(:respond_mode)).to be_falsey
    end
    it 'should not be rate mode if not submitted' do
      @u.update_attributes(:survey_edit=>true)
      sr = create(:survey_response, :survey=>create(:survey, :company=>@u.company))
      get :show, :id=>sr.id
      expect(assigns(:sr)).to eq(sr)
      expect(assigns(:rate_mode)).to be_falsey
      expect(assigns(:respond_mode)).to be_falsey
    end
    it "should not display if it doesn't pass the other tests" do
      sr = create(:survey_response)
      get :show, :id=>sr.id
      expect(response).to redirect_to root_path
      expect(flash[:errors].count).to eq(1)
    end
    it "should mark response_opened_date if current_user == survey_response.user and response_opened_date.nil?" do
      sr = create(:survey_response, :user=>@u)
      get :show, :id=>sr.id
      expect(SurveyResponse.find(sr.id).response_opened_date).to be > 2.minutes.ago
    end
    it "should mark response_opened_date if current_user is in response group and response_opened_date.nil?" do
      group = create(:group)
      @u.groups << group

      sr = create(:survey_response, group: group)
      get :show, :id=>sr.id
      expect(SurveyResponse.find(sr.id).response_opened_date).to be > 2.minutes.ago
    end
    it "should not change response_opened_date if already set" do
      d = 10.hours.ago
      sr = create(:survey_response, :user=>@u, :response_opened_date=>d)
      get :show, :id=>sr.id
      expect(SurveyResponse.find(sr.id).response_opened_date.to_i).to eq(d.to_i)
    end
    it "should not set respond mode if response is submitted" do
      sr = create(:survey_response, :user=>@u, :submitted_date=>0.seconds.ago)
      get :show, :id=>sr.id
      expect(assigns(:sr)).to eq(sr)
      expect(assigns(:respond_mode)).to be_falsey
    end
    it "should show error if user is using old IE version" do
      @request.user_agent = "Mozilla/5.0 (compatible; MSIE 8.0; Windows NT 6.1; Trident/4.0; GTB7.4; InfoPath.2; SV1; .NET CLR 3.3.69573; WOW64; en-US)"
      sr = create(:survey_response, :user=>@u)
      get :show, :id=>sr.id
      expect(response).to be_success
      expect(flash[:errors]).to include "You are using an unsupported version of Internet Explorer.  Upgrade to at least version 9 or consider using Google Chrome before filling in any survey answers."
    end
    context "json" do
      it "should load json response" do
        q = create(:question, survey:create(:survey, name:'myname', ratings_list:"a\nb", require_contact: true))
        sr = q.survey.generate_response! @u, 'subt'
        get :show, :id=>sr.id, :format=>:json
        expect(response).to be_success
        j = JSON.parse response.body
        srj = j['survey_response']
        expect(srj['survey']['name']).to eq(sr.survey.name)
        expect(srj['survey']['rating_values']).to eq(['a', 'b'])
        expect(srj['survey']['require_contact']).to eq(true)
        a = srj['answers'].first
        expect(a['question']['require_comment']).to be_falsey
        expect(a['question']['require_attachment']).to be_falsey
      end

      it "should remove private comments if user cannot edit" do
        allow_any_instance_of(SurveyResponse).to receive(:can_view?).and_return true
        allow_any_instance_of(SurveyResponse).to receive(:can_edit?).and_return false
        q = create(:question, survey:create(:survey, name:'myname', ratings_list:"a\nb"))
        sr = q.survey.generate_response! @u, 'subt'
        sr.answers.first.answer_comments.create!(content:'mycomment', private:false, user_id:@u.id)
        sr.answers.first.answer_comments.create!(content:'pcomment', private:true, user_id:@u.id)
        get :show, :id=>sr.id, :format=>:json
        expect(response).to be_success
        j = JSON.parse response.body
        ac = j['survey_response']['answers'].first['answer_comments']
        expect(ac.size).to eq(1)
        expect(ac.first['content']).to eq('mycomment')
      end

      it "should leave private comments if user can edit" do
        allow_any_instance_of(SurveyResponse).to receive(:can_view?).and_return true
        allow_any_instance_of(SurveyResponse).to receive(:can_edit?).and_return true
        q = create(:question, survey:create(:survey, name:'myname', ratings_list:"a\nb"))
        sr = q.survey.generate_response! @u, 'subt'
        sr.answers.first.answer_comments.create!(content:'mycomment', private:false, user_id:@u.id)
        sr.answers.first.answer_comments.create!(content:'pcomment', private:true, user_id:@u.id)
        get :show, :id=>sr.id, :format=>:json
        expect(response).to be_success
        j = JSON.parse response.body
        ac = j['survey_response']['answers'].first['answer_comments']
        expect(ac.size).to eq(2)
        expect(ac.collect {|c| c['content']}).to eq(['mycomment', 'pcomment'])
      end

      it "makes survey read only of takers if its checked out" do
        allow_any_instance_of(SurveyResponse).to receive(:can_view?).and_return true
        allow_any_instance_of(SurveyResponse).to receive(:can_edit?).and_return false

        sr = create(:survey_response, user: @u, checkout_by_user: @u)
        get :show, :id=>sr.id, :format=>:json

        expect(response).to be_success
        j = JSON.parse response.body
        expect(j['survey_response']['can_rate']).to be_falsey
        expect(j['survey_response']['can_answer']).to be_falsey
        expect(j['survey_response']['can_submit']).to be_falsey
        expect(j['survey_response']['can_comment']).to be_falsey
        expect(j['survey_response']['can_make_private_comment']).to be_falsey
      end

      it "makes survey read only to survey raters if its checked out" do
        allow_any_instance_of(SurveyResponse).to receive(:can_view?).and_return true
        allow_any_instance_of(SurveyResponse).to receive(:can_edit?).and_return true

        taker = create(:user)
        sr = create(:survey_response, user: taker, checkout_by_user: taker, submitted_date: Time.zone.now)
        get :show, :id=>sr.id, :format=>:json

        expect(response).to be_success
        j = JSON.parse response.body
        expect(j['survey_response']['can_rate']).to be_falsey
        expect(j['survey_response']['can_answer']).to be_falsey
        expect(j['survey_response']['can_submit']).to be_falsey
        expect(j['survey_response']['can_comment']).to be_falsey
        expect(j['survey_response']['can_make_private_comment']).to be_falsey
      end

      context "archived" do
        it "disables all can_* attributes on archived survey responses" do
          sr = create(:survey_response, user:@u, archived: true)
          get :show, :id=>sr.id, :format=>:json
          expect(response).to be_success
          j = JSON.parse response.body

          expect(j['survey_response']['archived']).to be_truthy
          expect(j['survey_response']['can_rate']).to be_falsey
          expect(j['survey_response']['can_answer']).to be_falsey
          expect(j['survey_response']['can_submit']).to be_falsey
          expect(j['survey_response']['can_make_private_comment']).to be_falsey
        end

        it "disables all can_* attributes on survey responses associated with an archvied survey" do
          sr = create(:survey_response, user:@u, archived: false)
          sr.survey.update_attributes! archived: true

          get :show, :id=>sr.id, :format=>:json
          expect(response).to be_success
          j = JSON.parse response.body

          expect(j['survey_response']['archived']).to be_truthy
          expect(j['survey_response']['can_rate']).to be_falsey
          expect(j['survey_response']['can_answer']).to be_falsey
          expect(j['survey_response']['can_submit']).to be_falsey
          expect(j['survey_response']['can_make_private_comment']).to be_falsey
        end
      end
    end
  end
  context 'authenticated' do
    before :each do

      @survey_user = create(:user, survey_edit: true)
      @survey = create(:survey, :company=>@survey_user.company)
      @survey.questions.create!(:content=>'1234567890123456')
      @response_user = create(:user)
      @sr = create(:survey_response, :user=>@response_user, :survey=>@survey)
      @sr.answers.create!(:question=>@survey.questions.first)
    end
    describe 'update' do
      it "should not save if user is not from survey company or the user assigned to the response" do
        sign_in_as create(:user)
        post :update, :id=>@sr.id
        expect(response).to redirect_to root_path
        expect(flash[:errors].size).to eq(1)
        expect(SurveyResponse.find(@sr.id).answers.first.choice).to be_nil
      end
      it "should not update submitted date if survey_response.user != current_user" do
        sign_in_as @survey_user
        post :update, {survey_response: {:id=>@sr.id}, id: @sr.id, do_submit: "1"}
        expect(SurveyResponse.find(@sr.id).submitted_date).to be_nil
      end
      it "should update submitted date if flag set and survey_response.user == current_user" do
        sign_in_as @response_user
        post :update, {survey_response: {:id=>@sr.id}, id: @sr.id, do_submit: "1"}
        expect(SurveyResponse.find(@sr.id).submitted_date).to be > 10.seconds.ago
      end
       it "should update submitted date if flag set and user is in survey response user group" do
        group_user = create(:user)
        group = create(:group)
        group_user.groups << group
        @sr.update_attributes! group: group
        sign_in_as group_user
        post :update, {survey_response: {:id=>@sr.id}, id: @sr.id, do_submit: "1"}
        expect(response).to redirect_to @sr
        expect(SurveyResponse.find(@sr.id).submitted_date).to be > 10.seconds.ago
      end
      it "should create update record" do
        sign_in_as @response_user
        post :update, {survey_response: {:id=>@sr.id}, id: @sr.id, do_submit: "1"}
        expect(SurveyResponse.find(@sr.id).survey_response_updates.first.user).to eq(@response_user)
      end
      it "allows user to update survey response header data" do
        sign_in_as @survey_user
        post :update, {survey_response: {address: "123", email: "me@there.com", phone: "708", fax: "987", name: "Test"}, id: @sr.id}
        expect(response).to redirect_to @sr
        @sr.reload
        expect(@sr.address).to eq "123"
        expect(@sr.email).to eq "me@there.com"
        expect(@sr.phone).to eq "708"
        expect(@sr.fax).to eq "987"
        expect(@sr.name).to eq "Test"
      end
      it "allows survey user to update survey response header data" do
        sign_in_as @survey_user
        post :update, {survey_response: {address: "123", email: "me@there.com", phone: "708", fax: "987", name: "Test", rating: "10"}, id: @sr.id}
        expect(response).to redirect_to @sr
        @sr.reload
        expect(@sr.address).to eq "123"
        expect(@sr.email).to eq "me@there.com"
        expect(@sr.phone).to eq "708"
        expect(@sr.fax).to eq "987"
        expect(@sr.name).to eq "Test"
        expect(@sr.rating).to be_blank
      end
      it "allows response user to update rating" do
        expect(subject).to receive(:can_rate?).and_return true

        sign_in_as @response_user
        post :update, {survey_response: {address: "123", email: "me@there.com", phone: "708", fax: "987", name: "Test", rating: "10"}, id: @sr.id}
        expect(response).to redirect_to @sr
        @sr.reload
        expect(@sr.address).to eq "123"
        expect(@sr.email).to eq "me@there.com"
        expect(@sr.phone).to eq "708"
        expect(@sr.fax).to eq "987"
        expect(@sr.name).to eq "Test"
        expect(@sr.rating).to eq "10"
      end
    end
    describe 'invite' do
      it "should allow survey company to send invite" do
        sign_in_as @survey_user
        expect_any_instance_of(SurveyResponse).to receive(:invite_user!)
        get :invite, :id=>@sr.id
        expect(response).to redirect_to @sr
      end
      it "should not allow another user to send invite" do
        sign_in_as @response_user
        expect_any_instance_of(SurveyResponse).not_to receive(:invite_user!)
        get :invite, :id=>@sr.id
        expect(response).to redirect_to request.referrer
      end
    end

    describe "archive" do
      it "should allow survey user to archive a survey response" do
        sign_in_as @survey_user
        put :archive, :id => @sr.id
        expect(@sr.reload.archived).to be_truthy
        expect(flash[:notices].first).to eq("The Survey Response for #{@response_user.full_name} has been archived.")
        expect(response).to redirect_to @survey
      end

      it "should not allow a user without edit privs to archive a survey response" do
        @survey_user.update_attributes survey_edit: false
        sign_in_as @survey_user
        put :archive, :id => @sr.id
        expect(@sr.reload.archived).to be_falsey
        expect(flash[:errors].first).to eq("You do not have permission to work with this survey.")
      end
    end

    describe "restore" do
      it "should allow survey user to restore a survey response" do
        sign_in_as @survey_user
        put :restore, :id => @sr.id
        expect(@sr.reload.archived).to be_falsey
        expect(flash[:notices].first).to eq("The Survey Response for #{@response_user.full_name} has been restored.")
        expect(response).to redirect_to @survey
      end

      it "should not allow a user without edit privs to archive a survey response" do
        @sr.archived = true
        @sr.save!

        @survey_user.update_attributes survey_edit: false
        sign_in_as @survey_user
        put :restore, :id => @sr.id
        expect(@sr.reload.archived).to be_truthy
        expect(flash[:errors].first).to eq("You do not have permission to work with this survey.")
      end
    end
  end
  describe 'index' do
    before :each do

      @u = create(:user)
      sign_in_as @u
    end
    it 'should only show survey responses assigned to current_user' do
      to_find = create(:survey_response, :user=>@u)
      dont_find = create(:survey_response)
      group = create(:group)
      @u.groups << group
      group_find = create(:survey_response, group: group)

      get :index
      expect(response).to be_success
      srs = assigns(:survey_responses).to_a
      expect(srs).to include to_find
      expect(srs).to include group_find
    end


    it "shows error if user is using IE < 9" do
      @request.user_agent = "Mozilla/5.0 (compatible; MSIE 8.0; Windows NT 6.1; Trident/4.0; GTB7.4; InfoPath.2; SV1; .NET CLR 3.3.69573; WOW64; en-US)"
      to_find = create(:survey_response, :user=>@u)
      get :index
      expect(response).to be_success
      expect(flash[:errors]).to include "You are using an unsupported version of Internet Explorer.  Upgrade to at least version 9 or consider using Google Chrome before filling in any survey answers."
    end
  end

  describe "remind", :disable_delayed_jobs do
    before(:each) do
      @u = create(:user)
      sign_in_as @u
      @sr = create(:survey_response, :user=>@u, survey: create(:survey, company: @u.company))
      @email_to = "joe@test.com sue@test.com"
      @email_subject = "Reminder: Important Survey"
      @email_body = "Please follow the link below to complete your survey."
    end

    it "restricts access" do
      expect(OpenMailer).not_to receive(:send_survey_reminder)
      post :remind, id: @sr.id, email_to: @email_to, email_subject: @email_subject, email_body: @email_body

      expect(flash[:errors]).to include "You do not have permission to work with this survey."
      expect(response).to redirect_to request.referrer
    end

    it "only sends with an email address" do
      allow(@u).to receive(:edit_surveys?).and_return true
      expect(OpenMailer).not_to receive(:send_survey_reminder)
      post :remind, id: @sr.id, email_to: "", email_subject: @email_subject, email_body: @email_body

      expect(JSON.parse(response.body)["error"]).to eq "Email address is required."
    end

    it "validates emails" do
      allow(@u).to receive(:edit_surveys?).and_return true
      expect(OpenMailer).not_to receive(:send_survey_reminder)
      post :remind, id: @sr.id, email_to: "joe@test sue@test.com", email_subject: @email_subject, email_body: @email_body

      expect(JSON.parse(response.body)["error"]).to eq "Invalid email. Be sure to separate multiple addresses with spaces."
    end

    it "sends custom emails to all recipients" do
      allow(@u).to receive(:edit_surveys?).and_return true
      stub_master_setup
      link_addr = "http://localhost:3000/survey_responses/#{@sr.id}"

      message_delivery = instance_double(ActionMailer::MessageDelivery)
      expect(OpenMailer).to receive(:send_survey_reminder).with(@sr, ["joe@test.com", "sue@test.com"], "Reminder: Important Survey", "Please follow the link below to complete your survey.").and_return message_delivery
      expect(message_delivery).to receive(:deliver_later)

      post :remind, id: @sr.id, email_to: @email_to, email_subject: @email_subject, email_body: @email_body
      expect(JSON.parse(response.body)["ok"]).to eq "ok"
    end
  end
end
