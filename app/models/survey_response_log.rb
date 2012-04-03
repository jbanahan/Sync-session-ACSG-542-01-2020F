class SurveyResponseLog < ActiveRecord::Base
  belongs_to :survey_response, :inverse_of=>:survey_response_logs
end
