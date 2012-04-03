class SurveyResponseLogsController < ApplicationController
  def index
    sr = SurveyResponse.find params[:survey_response_id]
    if sr.can_view? current_user
      @sr = sr
      @logs = sr.survey_response_logs.all
    else
      error_redirect "You do not have permission to view this survey response."
    end
  end
end
