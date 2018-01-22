# == Schema Information
#
# Table name: survey_response_logs
#
#  id                 :integer          not null, primary key
#  survey_response_id :integer
#  message            :text
#  created_at         :datetime
#  updated_at         :datetime
#  user_id            :integer
#
# Indexes
#
#  index_survey_response_logs_on_survey_response_id  (survey_response_id)
#  index_survey_response_logs_on_user_id             (user_id)
#

class SurveyResponseLog < ActiveRecord::Base
  belongs_to :survey_response, :inverse_of=>:survey_response_logs
  belongs_to :user
end
