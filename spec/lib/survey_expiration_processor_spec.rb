require 'spec_helper'

OpenMailer.deliveries.clear #Clean the inbox for the first test

describe OpenChain::SurveyExpirationProcessor do 

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

		it 'should send a total of six emails to subscribers' do
			OpenMailer.deliveries.length.should equal(6)
		end

		it 'should send an email to subscriber 1 of survey 1' do
			OpenMailer.deliveries[-6].to.first.should eq("survey_1_sub1@example.com")
		end

		it 'should send an email to subscriber 2 of survey 1' do
			OpenMailer.deliveries[-5].to.first.should eq("survey_1_sub2@example.com")
		end
		
		it 'should send an email to subscriber 3 of survey 1' do
			OpenMailer.deliveries[-4].to.first.should eq("survey_1_sub3@example.com")
		end
		
		it 'should send an email to subscriber 1 of survey 2' do
			OpenMailer.deliveries[-3].to.first.should eq("survey_2_sub1@example.com")
		end
		
		it 'should send an email to subscriber 2 of survey 2' do
			OpenMailer.deliveries[-2].to.first.should eq("survey_2_sub2@example.com")
		end
		
		it 'should send an email to subscriber 3 of survey 2' do
			OpenMailer.deliveries[-1].to.first.should eq("survey_2_sub3@example.com")
		end

		it 'should send the correct subject line for subscriber 1 of survey 1' do
			OpenMailer.deliveries[-6].subject.should == "Survey \"survey_1\" has 3 expired survey(s)."
		end

		it 'should send the correct subject line for subscriber 2 of survey 1' do
			OpenMailer.deliveries[-5].subject.should == "Survey \"survey_1\" has 3 expired survey(s)."
		end
		
		it 'should send the correct subject line for subscriber 3 of survey 1' do
			OpenMailer.deliveries[-4].subject.should == "Survey \"survey_1\" has 3 expired survey(s)."
		end
		
		it 'should send the correct subject line for subscriber 1 of survey 2' do
			OpenMailer.deliveries[-3].subject.should == "Survey \"survey_2\" has 3 expired survey(s)."
		end
		
		it 'should send the correct subject line for subscriber 2 of survey 2' do
			OpenMailer.deliveries[-2].subject.should == "Survey \"survey_2\" has 3 expired survey(s)."
		end
		
		it 'should send the correct subject line for subscriber 3 of survey 2' do
			OpenMailer.deliveries[-1].subject.should == "Survey \"survey_2\" has 3 expired survey(s)."
		end
		
		it 'should include the subtitle for subscriber 1 of survey 1' do
			OpenMailer.deliveries[-6].body.to_s.index("test subtitle 1.1").should_not be_nil
		end

		it 'should include a blank subtitle for subscriber 2 of survey 1' do
			OpenMailer.deliveries[-5].body.to_s.index("N/A").should_not be_nil
		end
		
		it 'should include the subtitle for subscriber 3 of survey 1' do
			OpenMailer.deliveries[-4].body.to_s.index("test subtitle 1.3").should_not be_nil
		end
		
		it 'should include the subtitle for subscriber 1 of survey 2' do
			OpenMailer.deliveries[-3].body.to_s.index("test subtitle 2.1").should_not be_nil
		end
		
		it 'should include a blank subtitle for subscriber 2 of survey 2' do
			OpenMailer.deliveries[-2].body.to_s.index("N/A").should_not be_nil
		end
		
		it 'should include the subtitle for subscriber 3 of survey 2' do
			OpenMailer.deliveries[-1].body.to_s.index("test subtitle 2.3").should_not be_nil
		end

		it 'should set expiration_notification_sent_at for survey 1 response 1' do
			#To explain why I didn't simply use @survey_1_response_1.expiration_notification_sent_at:
			#RSpec changes the memory location on you as it executes run_schedulable, so you can't
			#check the value just by checking the properties of @survey_1_response_1.
			(Time.now - SurveyResponse.find(@survey_1_response_1.id).expiration_notification_sent_at).should < 1.minutes
		end

		it 'should set expiration_notification_sent_at for survey 1 response 2' do
			(Time.now - SurveyResponse.find(@survey_1_response_2.id).expiration_notification_sent_at).should < 1.minutes
		end

		it 'should set expiration_notification_sent_at for survey 1 response 3' do
			(Time.now - SurveyResponse.find(@survey_1_response_3.id).expiration_notification_sent_at).should < 1.minutes
		end

		it 'should set expiration_notification_sent_at for survey 2 response 1' do
			(Time.now - SurveyResponse.find(@survey_2_response_1.id).expiration_notification_sent_at).should < 1.minutes
		end

		it 'should set expiration_notification_sent_at for survey 2 response 2' do
			(Time.now - SurveyResponse.find(@survey_2_response_2.id).expiration_notification_sent_at).should < 1.minutes
		end

		it 'should set expiration_notification_sent_at for survey 2 response 3' do
			(Time.now - SurveyResponse.find(@survey_2_response_3.id).expiration_notification_sent_at).should < 1.minutes
		end

	end
end