require 'spec_helper'

describe SurveyResponse do
  describe :last_logged_by_user do
    it "should find most recently saved message created_at associated with given user" do
      u = Factory(:user)
      t = 3.days.ago
      sr = Factory(:survey_response)
      srl = sr.survey_response_logs
      srl.create!(message:'earlier',user_id:u.id,created_at:10.days.ago)
      srl.create!(message:'findme',user_id:u.id,created_at:t)
      srl.create!(message:'newer no user')
      srl.create!(message:'newer different user',user_id:Factory(:user).id)
      sr.reload
      expect(sr.last_logged_by_user(u).to_i).to eq t.to_i
    end
  end
  describe :rated? do
    it "should return true if there is a master rating" do
      expect(Factory(:survey_response,:rating=>'abc')).to be_rated
    end
    it "should return false if there is no master rating or answers with ratings" do
      expect(Factory(:survey_response,:rating=>nil)).to_not be_rated
    end
    it "should return true if any answers have ratings" do
      expect(Factory(:answer,:rating=>'abc').survey_response).to be_rated
    end
  end
  it "should require survey" do
    expect(SurveyResponse.new(:user=>Factory(:user)).save).to be_false
  end
  it "should require user" do
    expect(SurveyResponse.new(:survey=>Factory(:survey)).save).to be_false
  end
  it "should protect date attributes" do
    sr = Factory(:survey_response)
    d = 1.day.ago
    d2 = 2.days.ago
    sr.email_sent_date = d
    sr.email_opened_date = d
    sr.response_opened_date = d
    sr.submitted_date = d
    sr.accepted_date = d

    sr.update_attributes(:updated_at=>d2,:email_sent_date=>d2,:email_opened_date=>d2,
      :response_opened_date=>d2,:submitted_date=>d2,:accepted_date=>d2)

    found = SurveyResponse.find sr.id
    expect(found.email_sent_date.to_i).to eq d.to_i
    expect(found.email_opened_date.to_i).to eq d.to_i
    expect(found.response_opened_date.to_i).to eq d.to_i
    expect(found.submitted_date.to_i).to eq d.to_i
    expect(found.accepted_date.to_i).to eq d.to_i
    expect(found.updated_at.to_i).to eq d2.to_i #this one isn't protected
  end
  describe "status" do
    before :each do
      s = Factory(:survey)
      Factory(:question,:survey=>s)
      Factory(:question,:survey=>s)
      u = Factory(:user)
      @sr = s.generate_response! u
    end
    it "should have Incomplete status" do
      expect(@sr.status).to eq "Incomplete"
    end
    it "should have Needs Rating" do
      @sr.submitted_date = 0.seconds.ago
      @sr.save!
      expect(@sr.status).to eq "Needs Rating"
    end
    it "should have Rated status" do
      @sr.submitted_date = 0.seconds.ago
      @sr.rating = "x"
      @sr.save!
      expect(@sr.status).to eq "Rated"
    end
  end
  describe "can_view?" do
    before :each do
      @survey = Factory(:survey)
      @response_user = Factory(:user)
      @sr = @survey.generate_response! @response_user
    end
    it "should pass if user is response user" do
      expect(@sr.can_view?(@response_user)).to be_true
    end
    it "should pass if user can view_survey? and survey is created by user's company" do
      other_user = Factory(:user, company:@survey.company,survey_view:true)
      expect(@sr.can_view?(other_user)).to be_true
    end
    it "should fail if user can view_survey? and survey is NOT created by user's company" do
      other_user = Factory(:user)
      expect(@sr.can_view?(other_user)).to be_false
    end
  end
  describe :search_secure do
    it "should find assigned to me, even if I cannot view_survey" do
      u = Factory(:user,survey_view:false)
      sr = Factory(:survey_response,user:u)
      expect(SurveyResponse.search_secure(u,SurveyResponse).to_a).to eq [sr]
    end
    it "should find where survey is created by my company and I can view" do
      u = Factory(:user,survey_view:true)
      sr = Factory(:survey_response,survey:Factory(:survey,company:u.company))
      expect(SurveyResponse.search_secure(u,SurveyResponse).to_a).to eq [sr]
    end
    it "should not find where survey is created by my company and I canNOT view surveys" do
      u = Factory(:user,survey_view:false)
      sr = Factory(:survey_response,survey:Factory(:survey,company:u.company))
      expect(SurveyResponse.search_secure(u,SurveyResponse).to_a).to eq []
    end
  end
  describe "can_edit?" do
    before :each do
      @survey = Factory(:survey)
      @response_user = Factory(:user)
      @sr = @survey.generate_response! @response_user
    end
    it "should pass if user is from the survey company and can edit surveys" do
      u = Factory(:user,:company=>@survey.company,:survey_edit=>true)
      expect(@sr.can_edit?(u)).to be_true
    end
    it "should fail if user is from the survey company and cannot edit surveys" do
      u = Factory(:user,:company=>@survey.company,:survey_edit=>false)
      expect(@sr.can_edit?(u)).to be_false
    end
    it "should fail if user is not from the survey company" do
      expect(@sr.can_edit?(Factory(:user,survey_edit:true))).to be_false
    end
    it "does not allow edit when survey is archvied" do
      u = Factory(:user,:company=>@survey.company,:survey_edit=>true)
      @survey.update_attributes! archived: true
      expect(@sr.can_edit?(u)).to be_false
    end
  end
  describe "can_view_private_comments?" do
    before :each do
      @survey = Factory(:survey)
      @response_user = Factory(:user)
      @sr = @survey.generate_response! @response_user
    end
    it "should pass if the user is from the survey company" do
      u = Factory(:user,:company=>@survey.company)
      expect(@sr.can_view_private_comments?(u)).to be_true
    end
    it "should fail if the user is not from the survey company" do
      expect(@sr.can_view_private_comments?(Factory(:user))).to be_false
    end
    it "should fail if the user is the response_user and is not from the survey company" do
      expect(@sr.can_view_private_comments?(@response_user)).to be_false
    end
  end
  describe "invite_user!" do
    before :each do
      MasterSetup.get.update_attributes(:request_host=>"a.b.c")
      @survey = Factory(:question).survey
      @survey.update_attributes(:email_subject=>"TEST SUBJ",:email_body=>"EMLBDY")
      @u = Factory(:user)
    end
    context "assigned to a user" do
      before :each do
        @response = @survey.generate_response! @u
        @response.invite_user!
      end
      it "should log that notification was sent" do
        expect(@response.survey_response_logs.collect{ |log| log.message}).to include("Invite sent to #{@u.email}")
      end
      it "should update email_sent_date if not set" do
        @response.reload
        expect(@response.email_sent_date).to be > 1.second.ago
      end
      it "should email user with survey email, body, and link" do
        last_delivery = ActionMailer::Base.deliveries.last
        expect(last_delivery.to).to eq [@u.email]
        expect(last_delivery.subject).to eq @survey.email_subject
        expect(last_delivery.body.raw_source).to include(@survey.email_body)
        expect(last_delivery.body.raw_source).to include("<a href='http://a.b.c/survey_responses/#{@response.id}'>http://a.b.c/survey_responses/#{@response.id}</a>")
      end
    end

    context "assigned to a group" do
      before :each do
        @group = Factory(:group)
        @u.groups << @group
        @u2 = Factory(:user, groups: [@group])

        @response = @survey.generate_group_response! @group
        @response.invite_user!
      end

      it "sends an email notification to all members of the group" do
        @response.reload
        expect(@response.survey_response_logs.collect{ |log| log.message}).to include "Invite sent to #{@u.email}, #{@u2.email}"
        expect(@response.email_sent_date.to_date).to eq Time.zone.now.to_date

        last_delivery = ActionMailer::Base.deliveries.last
        expect(last_delivery.to).to eq [@u.email, @u2.email]
        expect(last_delivery.subject).to eq @survey.email_subject
        expect(last_delivery.body.raw_source).to include @survey.email_body
        expect(last_delivery.body.raw_source).to include "<a href='http://a.b.c/survey_responses/#{@response.id}'>http://a.b.c/survey_responses/#{@response.id}</a>"
      end
    end
  end
  describe :was_archived do
    before :each do
      @survey = Factory(:question).survey
      @u = Factory(:user)
      @response = @survey.generate_response! @u
    end

    it "should return survey responses that are not archived" do
      expect(SurveyResponse.was_archived(false).first.id).to eq @response.id
    end

    it "should return survey responses that are archived" do
      expect(SurveyResponse.was_archived(true).first).to be_nil
      @response.archived= true
      @response.save!
      expect(SurveyResponse.was_archived(true).first.id).to eq @response.id
    end

    it "should return survey responses when run over the survey's collection" do
      expect(@survey.survey_responses.where("1=1").merge(SurveyResponse.was_archived(false)).first.id).to eq @response.id
      expect(@survey.survey_responses.where("1=1").merge(SurveyResponse.was_archived(true)).first).to be_nil

      @response.archived= true
      @response.save!
      expect(@survey.survey_responses.where("1=1").merge(SurveyResponse.was_archived(true)).first.id).to eq @response.id
      expect(@survey.survey_responses.where("1=1").merge(SurveyResponse.was_archived(false)).first).to be_nil
    end
  end

  describe "most_recent_user_log" do
    it "returns the newest log with a user_id associated with it" do
      @survey = Factory(:question).survey
      @u = Factory(:user)
      @response = @survey.generate_response! @u

      @response.survey_response_logs.create! message: "Message", updated_at: Time.zone.now
      l2 = @response.survey_response_logs.create! message: "Message", updated_at: Time.zone.now - 1.day, user: @u
      @response.survey_response_logs.create! message: "Message", updated_at: Time.zone.now - 2.days, user: @u

      expect(@response.most_recent_user_log).to eq l2
    end
  end

  describe "assigned_to_user?" do
    before :each do
      @survey = Factory(:question).survey
      @group = Factory(:group)
      @u = Factory(:user)
    end

    it "shows as assigned if user matches response user" do
      response = @survey.generate_response! @u
      expect(response.assigned_to_user? @u).to be_true
    end

    it "does not show as assigned if user is not response user" do
      response = @survey.generate_response! @u
      expect(response.assigned_to_user? Factory(:user)).to be_false
    end

    it "shows as assigned if user in in group assigned to response" do
      @u.groups << @group
      response = @survey.generate_group_response! @group
      expect(response.assigned_to_user? @u).to be_true
    end

    it "does not show as assigned if user is not in response group" do
      response = @survey.generate_group_response! @group
      expect(response.assigned_to_user? @u).to be_false
    end
  end

  describe "responder_name" do
    before :each do
      @survey = Factory(:question).survey
      @group = Factory(:group)
      @u = Factory(:user)
    end

    it "uses user name as responder when assigned to a user" do
      expect(@survey.generate_response!(@u).responder_name).to eq @u.full_name
    end

    it "uses group name as responder when assigned to a group" do
      expect(@survey.generate_group_response!(@group).responder_name).to eq @group.name
    end
  end

  describe "clear_expired_checkouts" do
    it "clears checkout information and logs expiration" do
      user = Factory(:user)
      sr = Factory(:survey_response, checkout_token: "token", checkout_by_user: user, checkout_expiration: Time.zone.now - 1.day)
      sr2 = Factory(:survey_response, checkout_token: "token", checkout_by_user: user, checkout_expiration: Time.zone.now - 1.day + 2.seconds)

      SurveyResponse.clear_expired_checkouts(Time.zone.now - 1.day + 1.second)

      sr.reload
      expect(sr.checkout_token).to be_nil
      expect(sr.checkout_by_user).to be_nil
      expect(sr.checkout_expiration).to be_nil
      expect(sr.survey_response_logs.first.message).to eq "Check out expired."
      expect(sr.survey_response_logs.first.user).to eq User.integration

      # Second one should still be checked out
      sr2.reload
      expect(sr2.checkout_token).to eq "token"
    end
  end

  describe '#not_expired' do
    it "should find unexpired survey responses" do
      u = Factory(:user)
      s = Factory(:survey,expiration_days:5)
      is_expired = s.generate_response! u
      is_expired.email_sent_date = 10.days.ago
      is_expired.save!
      not_expired = s.generate_response! u
      not_expired.email_sent_date = 2.days.ago
      not_expired.save!
      never_sent = s.generate_response! u
      no_expiration = Factory(:survey).generate_response! u
      expect(SurveyResponse.not_expired.order(:id)).to eq [not_expired,never_sent,no_expiration]
    end
  end
end
