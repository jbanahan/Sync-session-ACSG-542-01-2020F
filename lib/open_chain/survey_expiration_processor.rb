require 'set'

class OpenChain::SurveyExpirationProcessor
	def run_schedulable opts_hash={}
		surveys_with_expired_responses = Set.new # There's a high chance of repetition in the surveys; sets handle this best
		SurveyResponse.reminder_email_needed.each { |sr| surveys_with_expired_responses << sr.survey }
		surveys_with_expired_responses.each do |expired_survey|
			responses = expired_survey.survey_responses.reminder_email_needed
			recipient_addresses = expired_survey.survey_subscriptions.map{|ss| ss.user.email}.compact
			recipient_addresses.each do |recipient|
				OpenMailer.send_survey_expiration_reminder(recipient, expired_survey, responses).deliver!
			end
			responses.each do |response|
				response.expiration_notification_sent_at = Time.now
				response.save!
			end
		end
	end
end