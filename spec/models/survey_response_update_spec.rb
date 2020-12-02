describe SurveyResponseUpdate do
  describe "update_eligible scope" do
    let(:survey_response) { create(:survey_response) }
    let(:user) { create(:user) }

    it "returns items updated > 1 hour ago" do
      find_me = survey_response.survey_response_updates.create!(user_id: user.id, updated_at: 2.hours.ago)
      survey_response.survey_response_updates.create(user_id: create(:user).id)
      expect(described_class.update_eligible.all).to eq([find_me])
    end
  end

  describe "run_updates" do
    let(:quiet_email) { instance_double('email') }
    let(:user) { create(:user) }

    before do
      allow(quiet_email).to receive(:deliver_now)
    end

    context "subscription_tests" do
      before do
        allow(OpenMailer).to receive(:send_survey_user_update).and_return quiet_email
      end

      it "sends to subscribers" do
        create(:user)
        sr = create(:survey_response)
        ss = sr.survey.survey_subscriptions.create!(user: user)
        update = sr.survey_response_updates.create!(user: create(:user), updated_at: 2.hours.ago)

        # expectation
        eml = instance_double('email')
        expect(eml).to receive(:deliver_now)
        expect(OpenMailer).to receive(:send_survey_subscription_update).with(sr, [update], [ss]).and_return(eml)

        # run
        described_class.run_updates
      end

      it "does not send to subscribers if there aren't any" do
        # setup
        sr = create(:survey_response)
        sr.survey_response_updates.create!(user: user, updated_at: 2.hours.ago)

        # expectation
        expect(OpenMailer).not_to receive(:send_survey_subscription_update)

        # run
        described_class.run_updates
      end

      it "does not send to subscriber if subscriber is the only updater" do
        # setup
        u2 = create(:user)
        sr = create(:survey_response)
        sr.survey.survey_subscriptions.create!(user: user)
        ss2 = sr.survey.survey_subscriptions.create!(user: u2)
        update = sr.survey_response_updates.create!(user: user, updated_at: 2.hours.ago)

        # expectation
        eml = instance_double('email')
        expect(eml).to receive(:deliver_now)
        expect(OpenMailer).to receive(:send_survey_subscription_update).with(sr, [update], [ss2]).and_return(eml)

        # run
        described_class.run_updates
      end

      it "sends to subscriber if the subscriber updated and another user also updated" do
        create(:user)
        sr = create(:survey_response)
        ss = sr.survey.survey_subscriptions.create!(user: user)
        update = sr.survey_response_updates.create!(user: user, updated_at: 2.hours.ago)
        update2 = sr.survey_response_updates.create!(user: create(:user), updated_at: 2.hours.ago)

        eml = instance_double('email')
        expect(eml).to receive(:deliver_now)
        expect(OpenMailer).to receive(:send_survey_subscription_update).with(sr, [update, update2], [ss]).and_return(eml)

        described_class.run_updates
      end
    end

    context "survey_user" do
      let(:quiet_email) { instance_double('email') }

      before do
        allow(quiet_email).to receive(:deliver_now)
        allow(OpenMailer).to receive(:send_survey_subscription_update).and_return(quiet_email)
      end

      it "sends to survey recipient if someone else updated" do
        sr = create(:survey_response, user: user)
        sr.survey_response_updates.create!(user: user, updated_at: 2.hours.ago)
        sr.survey_response_updates.create!(user: create(:user), updated_at: 2.hours.ago)

        eml = instance_double('email')
        expect(eml).to receive(:deliver_now)
        allow(OpenMailer).to receive(:send_survey_user_update).with(sr).and_return(eml)

        described_class.run_updates
      end

      it "does not send to survey recipient if status == NEEDS_RATING" do
        sr = create(:survey_response, user: user)
        allow_any_instance_of(SurveyResponse).to receive(:status).and_return(SurveyResponse::STATUSES[:needs_rating])
        sr.survey_response_updates.create!(user: create(:user), updated_at: 2.hours.ago)

        expect(OpenMailer).not_to receive(:send_survey_user_update)

        described_class.run_updates
      end

      it "does not send to survey recipient if only the recipient updated" do
        # setup
        sr = create(:survey_response, user: user)
        sr.survey_response_updates.create!(user: user, updated_at: 2.hours.ago)

        # expectation
        expect(OpenMailer).not_to receive(:send_survey_user_update)

        # run
        described_class.run_updates
      end
    end
  end

  describe "run_schedulable" do
    it "implements SchedulableJob interface" do
      expect(described_class).to receive(:run_updates)
      described_class.run_schedulable
    end
  end
end
