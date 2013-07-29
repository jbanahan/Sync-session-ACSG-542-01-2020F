class SurveyResponsesController < ApplicationController
  def show
    @sr = SurveyResponse.find params[:id]
    if @sr.user_id != current_user.id && (@sr.survey.company_id!=current_user.company_id || !current_user.edit_surveys?)
      error_redirect "You do not have permission to work with this survey."
      return
    end
    if @sr.user_id == current_user.id
      if @sr.response_opened_date.nil?
        @sr.response_opened_date = 0.seconds.ago 
        @sr.save
      end
      @respond_mode = true unless @sr.submitted_date
    elsif @sr.submitted_date && current_user.edit_surveys? && @sr.survey.company_id == current_user.company_id
      @rate_mode = true
    end
  end
  
  def update
    sr = SurveyResponse.find params[:id]
    if sr.survey.company_id!=current_user.company_id && sr.user!=current_user
      error_redirect "You do not have permission to work with this survey."
      return
    end
    if params[:survey_response][:answers_attributes]
      params[:survey_response][:answers_attributes].values.each do |v|
        
        #remove ratings if not survey owner company
        v.delete "rating" if sr.survey.company_id!=current_user.company_id
        
        #remove choices if current_user!=sr.user 
        v.delete "choice" if sr.user!=current_user

        aca = v[:answer_comments_attributes]
        if aca
          aca.each do |k,cv|
            aca.delete k unless cv[:user_id].to_s==current_user.id.to_s
          end
        end
      end
    end
    log_message = "Response saved."
    if sr.user==current_user
      if params[:do_submit]
        sr.submitted_date = 0.seconds.ago 
        log_message = "Response submitted."
      end
    end
    sr.update_attributes params[:survey_response]
    sr.survey_response_logs.create!(:message=>log_message,:user_id=>current_user.id)
    OpenMailer.delay.send_survey_user_update(sr) unless sr.user==current_user
    add_flash :notices, "Response saved successfully."
    redirect_to sr
  end

  def index
    @survey_responses = SurveyResponse.where(:user_id=>current_user.id)
  end
  
  #send user invite
  def invite
    sr = SurveyResponse.find params[:id]
    if sr.survey.company_id!=current_user.company_id
      error_redirect "You do not have permission to send invites for this survey."
      return
    else
      sr.invite_user!
      add_flash :notices, "Invite will be resent to the user at #{sr.user.email}"
      redirect_to sr
    end
  end

end
