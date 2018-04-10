# == Schema Information
#
# Table name: survey_response_logs
#
#  created_at         :datetime         not null
#  id                 :integer          not null, primary key
#  message            :text
#  survey_response_id :integer
#  updated_at         :datetime         not null
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
