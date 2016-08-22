require 'spec_helper'

describe SurveyResponseUpdate do
  describe "update_eligible scope" do
    before :each do
      @sr = Factory(:survey_response)
      @u = Factory(:user)
    end
    it "should return items updated > 1 hour ago" do
      find_me = @sr.survey_response_updates.create!(user_id:@u.id,updated_at:2.hours.ago)
      dont_find = @sr.survey_response_updates.create(user_id:Factory(:user).id)
      expect(described_class.update_eligible.all).to eq([find_me])
    end
  end
  describe "run_updates" do
    before :each do
      @quiet_email = double('email')
      allow(@quiet_email).to receive(:deliver)
      @u = Factory(:user)
    end
    context "subscription_tests" do
      before :each do
        allow(OpenMailer).to receive(:send_survey_user_update).and_return @quiet_email
      end
      it "should send to subscribers" do
        #setup
        u2 = Factory(:user)
        sr = Factory(:survey_response)
        ss = sr.survey.survey_subscriptions.create!(user:@u)
        update = sr.survey_response_updates.create!(user:Factory(:user),updated_at:2.hours.ago)

        #expectation
        eml = double('email')
        expect(eml).to receive(:deliver)
        expect(OpenMailer).to receive(:send_survey_subscription_update).with(sr, [update], [ss]).and_return(eml)

        #run
        described_class.run_updates
      end
      it "should not send to subscribers if there aren't any" do
        #setup
        sr = Factory(:survey_response)
        sr.survey_response_updates.create!(user:@u,updated_at:2.hours.ago)

        #expectation
        expect(OpenMailer).not_to receive(:send_survey_subscription_update)

        #run
        described_class.run_updates
      end
      it "should not send to subscriber if subscriber is the only updater" do
        #setup
        u2 = Factory(:user)
        sr = Factory(:survey_response)
        ss1 = sr.survey.survey_subscriptions.create!(user:@u)
        ss2 = sr.survey.survey_subscriptions.create!(user:u2)
        update = sr.survey_response_updates.create!(user:@u,updated_at:2.hours.ago)

        #expectation
        eml = double('email')
        expect(eml).to receive(:deliver)
        expect(OpenMailer).to receive(:send_survey_subscription_update).with(sr, [update], [ss2]).and_return(eml)

        #run
        described_class.run_updates
      end
      it "should send to subscriber if the subscriber updated and another user also updated" do
        #setup
        u2 = Factory(:user)
        sr = Factory(:survey_response)
        ss = sr.survey.survey_subscriptions.create!(user:@u)
        update = sr.survey_response_updates.create!(user:@u,updated_at:2.hours.ago)
        update2 = sr.survey_response_updates.create!(user:Factory(:user),updated_at:2.hours.ago)

        #expectation
        eml = double('email')
        expect(eml).to receive(:deliver)
        expect(OpenMailer).to receive(:send_survey_subscription_update).with(sr, [update, update2], [ss]).and_return(eml)

        #run
        described_class.run_updates
      end
    end
    context "survey_user" do
      before :each do
        quiet_email = double('email')
        allow(quiet_email).to receive(:deliver)
        allow(OpenMailer).to receive(:send_subscription_updates).and_return(quiet_email)
      end
      it "should send to survey recipent if someone else updated" do
        #setup
        sr = Factory(:survey_response,user:@u)
        sr.survey_response_updates.create!(user:@u,updated_at:2.hours.ago)
        sr.survey_response_updates.create!(user:Factory(:user),updated_at:2.hours.ago)

        #expectation
        eml = double('email')
        expect(eml).to receive(:deliver)
        expect(OpenMailer).to receive(:send_survey_user_update).with(sr).and_return(eml)

        #run
        described_class.run_updates
      end
      it "should not send to survey recipient if status == NEEDS_RATING" do
        #setup
        sr = Factory(:survey_response,user:@u)
        allow_any_instance_of(SurveyResponse).to receive(:status).and_return(SurveyResponse::STATUSES[:needs_rating])
        sr.survey_response_updates.create!(user:Factory(:user),updated_at:2.hours.ago)

        #expectation
        expect(OpenMailer).not_to receive(:send_survey_user_update)

        #run
        described_class.run_updates
      end
      it "should not send to survey recipient if only the recipient updated" do
        #setup
        sr = Factory(:survey_response,user:@u)
        sr.survey_response_updates.create!(user:@u,updated_at:2.hours.ago)

        #expectation
        expect(OpenMailer).not_to receive(:send_survey_user_update)

        #run
        described_class.run_updates
      end
    end
  end

  describe "run_schedulable" do
    it "implements SchedulableJob interface" do
      expect(SurveyResponseUpdate).to receive(:run_updates)
      SurveyResponseUpdate.run_schedulable
    end
  end
end
