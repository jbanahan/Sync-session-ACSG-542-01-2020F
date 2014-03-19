require 'spec_helper'

describe OpenChain::SurveyExpirationProcessor, type: :mailer do 

	before :each do
		/ Set up the 'ecosystem' for the test:
			Set up six users who will be our subscribers.
			Create two surveys, and subscribe three users to each. 
			Create some survey responses and set back the email_sent_date on them 
			such that they are seen as expired. /
		@survey_1_sub1 = Factory(:user, email: "survey_1_sub1@example.com")
		@survey_1_sub2 = Factory(:user, email: "survey_1_sub2@example.com")
		@survey_1_sub3 = Factory(:user, email: "survey_1_sub3@example.com")
		@survey_2_sub1 = Factory(:user, email: "survey_2_sub1@example.com")
		@survey_2_sub2 = Factory(:user, email: "survey_2_sub2@example.com")
		@survey_2_sub3 = Factory(:user, email: "survey_2_sub3@example.com")
		@survey_1 = Factory(:survey,:name=>"survey_1",:email_subject=>"survey_1_subject",:email_body=>"survey_1_body",:ratings_list=>"survey_1_rating", expiration_days: 1)
		@survey_2 = Factory(:survey,:name=>"survey_2",:email_subject=>"survey_2_subject",:email_body=>"survey_2_body",:ratings_list=>"survey_2_rating", expiration_days: 1)
		SurveySubscription.create!(:survey_id => @survey_1.id, :user_id => @survey_1_sub1.id)
		SurveySubscription.create!(:survey_id => @survey_1.id, :user_id => @survey_1_sub2.id)
		SurveySubscription.create!(:survey_id => @survey_1.id, :user_id => @survey_1_sub3.id)
		SurveySubscription.create!(:survey_id => @survey_2.id, :user_id => @survey_2_sub1.id)
		SurveySubscription.create!(:survey_id => @survey_2.id, :user_id => @survey_2_sub2.id)
		SurveySubscription.create!(:survey_id => @survey_2.id, :user_id => @survey_2_sub3.id)
		@survey_1_response_1 = Factory(:survey_response, rating: "survey_1_response_1_rating", survey: @survey_1, email_sent_date: Time.now - 3.days, subtitle: "test subtitle 1.1")
		@survey_1_response_2 = Factory(:survey_response, rating: "survey_1_response_2_rating", survey: @survey_1, email_sent_date: Time.now - 3.days)
		@survey_1_response_3 = Factory(:survey_response, rating: "survey_1_response_3_rating", survey: @survey_1, email_sent_date: Time.now - 3.days, subtitle: "test subtitle 1.3")
		@survey_2_response_1 = Factory(:survey_response, rating: "survey_2_response_1_rating", survey: @survey_2, email_sent_date: Time.now - 3.days, subtitle: "test subtitle 2.1")
		@survey_2_response_2 = Factory(:survey_response, rating: "survey_2_response_2_rating", survey: @survey_2, email_sent_date: Time.now - 3.days)
		@survey_2_response_3 = Factory(:survey_response, rating: "survey_2_response_3_rating", survey: @survey_2, email_sent_date: Time.now - 3.days, subtitle: "test subtitle 2.3")
		@p = OpenChain::SurveyExpirationProcessor.new
		@p.run_schedulable
	end

	describe :run_schedulable do

		it 'sends emails to subscribers if survey is expiring' do
      # Combining all the checks into a single example to save runtime
			OpenMailer.deliveries.length.should equal(6)
      expect(OpenMailer.deliveries.collect {|m| m.to}.flatten).to eq ["survey_1_sub1@example.com", "survey_1_sub2@example.com", 
          "survey_1_sub3@example.com", "survey_2_sub1@example.com", "survey_2_sub2@example.com", "survey_2_sub3@example.com"]
      expect(OpenMailer.deliveries.collect {|m| m.subject}).to eq ['Survey "survey_1" has 3 expired survey(s).', 'Survey "survey_1" has 3 expired survey(s).', 
        'Survey "survey_1" has 3 expired survey(s).', 'Survey "survey_2" has 3 expired survey(s).', 
        'Survey "survey_2" has 3 expired survey(s).', 'Survey "survey_2" has 3 expired survey(s).']

      SurveyResponse.all.each do |sr|
        expect(sr.expiration_notification_sent_at).to be > 1.minute.ago
      end
		end

	end
end