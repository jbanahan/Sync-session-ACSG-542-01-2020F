class AddExpirationNotificationSentAtToSurveyResponses < ActiveRecord::Migration
  def change
    add_column :survey_responses, :expiration_notification_sent_at, :datetime
  end
end
