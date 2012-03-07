class SurveyResponsesController < ApplicationController
  def show
    @sr = SurveyResponse.find params[:id]
    if @sr.user_id == current_user.id
      @respond_mode = true
    elsif current_user.edit_surveys? && @sr.survey.company_id == current_user.company_id
      @rate_mode = true
    else
      error_redirect "You do not have permission to work with this survey."
    end
  end
  
  def index
    @survey_responses = SurveyResponse.where(:user_id=>current_user.id)
  end

end
