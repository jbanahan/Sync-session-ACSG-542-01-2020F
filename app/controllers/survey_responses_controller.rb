class SurveyResponsesController < ApplicationController
  def show
    @sr = SurveyResponse.find params[:id]
    if @sr.user_id == current_user.id
      @sr.update_attributes(:response_opened_date=>0.seconds.ago) if @sr.response_opened_date.nil?
      @respond_mode = true unless @sr.submitted_date
    elsif current_user.edit_surveys? && @sr.survey.company_id == current_user.company_id
      @rate_mode = true
    else
      error_redirect "You do not have permission to work with this survey."
    end
  end
  
  def update
    sr = SurveyResponse.find params[:id]
    if sr.survey.company_id!=current_user.company_id && sr.user!=current_user
      error_redirect "You do not have permission to work with this survey."
      return
    end
    if sr.survey.company_id!=current_user.company_id
      #remove ratings if not survey owner company
      if params[:survey_response][:answers_attributes]
        params[:survey_response][:answers_attributes].values.each do |v|
          v.delete "rating"
        end
      end
    end
    if sr.user!=current_user
      #remove choices if current_user!=sr.user 
      if params[:survey_response][:answers_attributes]
        params[:survey_response][:answers_attributes].values.each do |v|
          v.delete "choice"
        end
      end
    end
    sr.update_attributes params[:survey_response]
    add_flash :notices, "Response saved successfully."
    redirect_to sr
  end

  def index
    @survey_responses = SurveyResponse.where(:user_id=>current_user.id)
  end

end
