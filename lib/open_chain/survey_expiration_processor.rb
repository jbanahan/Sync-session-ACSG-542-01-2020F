class OpenChain::SurveyExpirationProcessor
	def run_schedulable
		surveys_with_expired_responses = []
		SurveyResponse.reminder_email_needed.each do |sr| 
			surveys_with_expired_responses << sr.survey unless surveys_with_expired_responses.include? sr.survey
		end
		surveys_with_expired_responses.each do |expired_survey|
			recipient_addresses = []
			expired_survey.survey_subscriptions.each { |survey_subscription| recipient_addresses << survey_subscription.user.email }
			recipient_addresses.each do |recipient|
				OpenMailer.send_survey_expiration_reminder(recipient, expired_survey, expired_survey.survey_responses.reminder_email_needed).deliver!
			end
			expired_survey.survey_responses.reminder_email_needed.each do |response|
				response.expiration_notification_sent_at = Time.now
				response.save!
			end
		end
	end
end