describe SurveyResponse do
  describe "last_logged_by_user" do
    it "finds most recently saved message created_at associated with given user" do
      u = Factory(:user)
      t = 3.days.ago
      sr = Factory(:survey_response)
      srl = sr.survey_response_logs
      srl.create!(message: 'earlier', user_id: u.id, created_at: 10.days.ago)
      srl.create!(message: 'findme', user_id: u.id, created_at: t)
      srl.create!(message: 'newer no user')
      srl.create!(message: 'newer different user', user_id: Factory(:user).id)
      sr.reload
      expect(sr.last_logged_by_user(u).to_i).to eq t.to_i
    end
  end

  describe "rated?" do
    it "returns true if there is a master rating" do
      expect(Factory(:survey_response, rating: 'abc')).to be_rated
    end

    it "returns false if there is no master rating or answers with ratings" do
      expect(Factory(:survey_response, rating: nil)).not_to be_rated
    end

    it "returns true if any answers have ratings" do
      expect(Factory(:answer, rating: 'abc').survey_response).to be_rated
    end
  end

  it "requires survey" do
    expect(described_class.new(user: Factory(:user)).save).to be_falsey
  end

  it "requires user" do
    expect(described_class.new(survey: Factory(:survey)).save).to be_falsey
  end

  describe "status" do
    let(:survey_response) do
      s = Factory(:survey)
      Factory(:question, survey: s)
      Factory(:question, survey: s)
      u = Factory(:user)
      sr = s.generate_response! u
      sr
    end

    it "has Incomplete status" do
      expect(survey_response.status).to eq "Incomplete"
    end

    it "has Needs Rating" do
      survey_response.submitted_date = 0.seconds.ago
      survey_response.save!
      expect(survey_response.status).to eq "Needs Rating"
    end

    it "has Rated status" do
      survey_response.submitted_date = 0.seconds.ago
      survey_response.rating = "x"
      survey_response.save!
      expect(survey_response.status).to eq "Rated"
    end
  end

  describe "can_view?" do
    let(:survey) { Factory(:survey) }
    let(:response_user) { Factory(:user) }
    let(:survey_response) { survey.generate_response! response_user }

    it "passes if user is response user" do
      expect(survey_response.can_view?(response_user)).to be_truthy
    end

    it "passes if user can view_survey? and survey is created by user's company" do
      other_user = Factory(:user, company: survey.company, survey_view: true)
      expect(survey_response.can_view?(other_user)).to be_truthy
    end

    it "fails if user can view_survey? and survey is NOT created by user's company" do
      other_user = Factory(:user)
      expect(survey_response.can_view?(other_user)).to be_falsey
    end
  end

  describe "search_secure" do
    it "finds assigned to me, even if I cannot view_survey" do
      u = Factory(:user, survey_view: false)
      sr = Factory(:survey_response, user: u)
      expect(described_class.search_secure(u, described_class).to_a).to eq [sr]
    end

    it "finds where survey is created by my company and I can view" do
      u = Factory(:user, survey_view: true)
      sr = Factory(:survey_response, survey: Factory(:survey, company: u.company))
      expect(described_class.search_secure(u, described_class).to_a).to eq [sr]
    end

    it "does not find where survey is created by my company and I canNOT view surveys" do
      u = Factory(:user, survey_view: false)
      Factory(:survey_response, survey: Factory(:survey, company: u.company))
      expect(described_class.search_secure(u, described_class).to_a).to eq []
    end
  end

  describe "can_edit?" do
    let(:survey) { Factory(:survey) }
    let(:response_user) { Factory(:user) }
    let(:survey_response) { survey.generate_response! response_user }

    it "passes if user is from the survey company and can edit surveys" do
      u = Factory(:user, company: survey.company, survey_edit: true)
      expect(survey_response.can_edit?(u)).to be_truthy
    end

    it "fails if user is from the survey company and cannot edit surveys" do
      u = Factory(:user, company: survey.company, survey_edit: false)
      expect(survey_response.can_edit?(u)).to be_falsey
    end

    it "fails if user is not from the survey company" do
      expect(survey_response.can_edit?(Factory(:user, survey_edit: true))).to be_falsey
    end

    it "does not allow edit when survey is archvied" do
      u = Factory(:user, company: survey.company, survey_edit: true)
      survey.update! archived: true
      expect(survey_response.can_edit?(u)).to be_falsey
    end
  end

  describe "can_view_private_comments?" do
    let(:survey) { Factory(:survey) }
    let(:response_user) { Factory(:user) }
    let(:survey_response) { survey.generate_response! response_user }

    it "passes if the user is from the survey company" do
      u = Factory(:user, company: survey.company)
      expect(survey_response.can_view_private_comments?(u)).to be_truthy
    end

    it "fails if the user is not from the survey company" do
      expect(survey_response.can_view_private_comments?(Factory(:user))).to be_falsey
    end

    it "fails if the user is the response_user and is not from the survey company" do
      expect(survey_response.can_view_private_comments?(response_user)).to be_falsey
    end
  end

  describe "invite_user!" do
    let!(:master_setup) { stub_master_setup } # rubocop:disable RSpec/LetSetup

    let(:survey) do
      survey = Factory(:question).survey
      survey.update(email_subject: "TEST SUBJ", email_body: "EMLBDY")
      survey
    end

    let(:user) { Factory(:user) }

    context "assigned to a user" do
      let(:now) { Time.zone.now }
      let(:response) do
        response = survey.generate_response! user
        response.invite_user!
        response
      end

      before do
        Timecop.freeze(now) do
          response
        end
      end

      it "logs that notification was sent" do
        expect(response.survey_response_logs.collect(&:message)).to include("Invite sent to #{user.email}")
      end

      it "updates email_sent_date if not set" do
        response.reload
        expect(response.email_sent_date.to_i).to eq now.to_i
      end

      it "emails user with survey email, body, and link" do
        last_delivery = ActionMailer::Base.deliveries.last
        expect(last_delivery.to).to eq [user.email]
        expect(last_delivery.subject).to eq survey.email_subject
        expect(last_delivery.body.raw_source).to include(survey.email_body)
        expect(last_delivery.body.raw_source)
          .to include("<a href='https://localhost:3000/survey_responses/#{response.id}'>https://localhost:3000/survey_responses/#{response.id}</a>")
      end
    end

    context "assigned to a group" do
      let(:user2) { Factory(:user) }

      let(:group) do
        group = Factory(:group)
        user.groups << group
        user2
        user2.groups << group
        group
      end

      let(:response) do
        response = survey.generate_group_response! group
        response.invite_user!
        response
      end

      it "sends an email notification to all members of the group" do
        response.reload
        expect(response.survey_response_logs.collect(&:message)).to include "Invite sent to #{user.email}, #{user2.email}"
        expect(response.email_sent_date.to_date).to eq Time.zone.now.to_date

        last_delivery = ActionMailer::Base.deliveries.last
        expect(last_delivery.to).to eq [user.email, user2.email]
        expect(last_delivery.subject).to eq survey.email_subject
        expect(last_delivery.body.raw_source).to include survey.email_body
        expect(last_delivery.body.raw_source)
          .to include "<a href='https://localhost:3000/survey_responses/#{response.id}'>https://localhost:3000/survey_responses/#{response.id}</a>"
      end
    end
  end

  describe "was_archived" do
    let(:survey) { Factory(:question).survey }
    let(:user) { Factory(:user) }
    let!(:response) { survey.generate_response! user }

    it "returns survey responses that are not archived" do
      expect(described_class.was_archived(false).first.id).to eq response.id
    end

    it "returns survey responses that are archived" do
      expect(described_class.was_archived(true).first).to be_nil
      response.archived = true
      response.save!
      expect(described_class.was_archived(true).first.id).to eq response.id
    end

    it "returns survey responses when run over the survey's collection" do
      expect(survey.survey_responses.where("1=1").merge(described_class.was_archived(false)).first.id).to eq response.id
      expect(survey.survey_responses.where("1=1").merge(described_class.was_archived(true)).first).to be_nil

      response.archived = true
      response.save!
      expect(survey.survey_responses.where("1=1").merge(described_class.was_archived(true)).first.id).to eq response.id
      expect(survey.survey_responses.where("1=1").merge(described_class.was_archived(false)).first).to be_nil
    end
  end

  describe "most_recent_user_log" do
    it "returns the newest log with a user_id associated with it" do
      Timecop.freeze(Time.zone.now) do
        survey = Factory(:question).survey
        user = Factory(:user)
        response = survey.generate_response! user

        response.survey_response_logs.create! message: "Message", updated_at: Time.zone.now
        l2 = response.survey_response_logs.create! message: "Message", updated_at: Time.zone.now - 1.day, user: user
        response.survey_response_logs.create! message: "Message", updated_at: Time.zone.now - 2.days, user: user

        expect(response.most_recent_user_log).to eq l2
      end
    end
  end

  describe "assigned_to_user?" do
    let(:survey) { Factory(:question).survey }
    let(:group) { Factory(:group) }
    let(:user) { Factory(:user) }

    it "shows as assigned if user matches response user" do
      response = survey.generate_response! user
      expect(response.assigned_to_user?(user)).to be_truthy
    end

    it "does not show as assigned if user is not response user" do
      response = survey.generate_response! user
      expect(response.assigned_to_user?(Factory(:user))).to be_falsey
    end

    it "shows as assigned if user in in group assigned to response" do
      user.groups << group
      response = survey.generate_group_response! group
      expect(response.assigned_to_user?(user)).to be_truthy
    end

    it "does not show as assigned if user is not in response group" do
      response = survey.generate_group_response! group
      expect(response.assigned_to_user?(user)).to be_falsey
    end
  end

  describe "responder_name" do
    let(:survey) { Factory(:question).survey }
    let(:group) { Factory(:group) }
    let(:user) { Factory(:user) }

    it "uses user name as responder when assigned to a user" do
      expect(survey.generate_response!(user).responder_name).to eq user.full_name
    end

    it "uses group name as responder when assigned to a group" do
      expect(survey.generate_group_response!(group).responder_name).to eq group.name
    end
  end

  describe "clear_expired_checkouts" do
    it "clears checkout information and logs expiration" do
      now = Time.zone.now

      sr = nil
      sr2 = nil
      Timecop.freeze(now) do
        user = Factory(:user)
        sr = Factory(:survey_response, checkout_token: "token", checkout_by_user: user, checkout_expiration: now - 1.day)
        sr2 = Factory(:survey_response, checkout_token: "token", checkout_by_user: user, checkout_expiration: now - 1.day + 2.seconds)

        described_class.clear_expired_checkouts(now - 1.day + 1.second)
      end

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
    it "finds unexpired survey responses" do
      u = Factory(:user)
      s = Factory(:survey, expiration_days: 5)
      is_expired = s.generate_response! u
      is_expired.email_sent_date = 10.days.ago
      is_expired.save!
      not_expired = s.generate_response! u
      not_expired.email_sent_date = 2.days.ago
      not_expired.save!
      never_sent = s.generate_response! u
      no_expiration = Factory(:survey).generate_response! u
      expect(described_class.not_expired.order(:id)).to eq [not_expired, never_sent, no_expiration]
    end
  end
end
