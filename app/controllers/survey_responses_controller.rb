class SurveyResponsesController < ApplicationController
  include SurveyResponsesControllerSupport

  def show
    sr = nil
    begin
      sr = show_survey_response params[:id], current_user
    rescue StatusableError => e
      error_redirect e.message
      return
    end

    respond_to do |format|
      format.html do
        @sr = sr
        @respond_mode = respond_mode?(sr, current_user)
        @rate_mode = rate_mode?(sr, current_user)

        if old_ie_version? 
          add_flash :errors, "You are using an unsupported version of Internet Explorer.  Upgrade to at least version 9 or consider using Google Chrome before filling in any survey answers.", now: true
        end
        
        @no_action_bar = true
      end

      format.json do 
        render json: json_survey_response(sr, current_user)
      end
    end
  end
  
  def update
    sr = SurveyResponse.find params[:id]
    if !sr.can_view?(current_user) && !sr.can_edit?(current_user)
      error_redirect "You do not have permission to work with this survey."
      return
    end

    Lock.with_lock_retry(sr) do
      if sr.assigned_to_user?(current_user) && params[:do_submit]
        if submit_survey_response sr, current_user
          sr.save
        end
      else
        sr.update_attributes params[:survey_response]
        sr.survey_response_logs.create!(:message=>"Response saved.",:user=>current_user)
        sr.log_update current_user
      end
    end
    
    add_flash :notices, "Response saved successfully."
    respond_to do |format|
      format.html {redirect_to sr}
      format.json {render json: {ok:'ok'}}
    end
    
  end

  def index
    if old_ie_version? 
      add_flash :errors, "You are using an unsupported version of Internet Explorer.  Upgrade to at least version 9 or consider using Google Chrome before filling in any survey answers.", now: true
    end
    @survey_responses = survey_responses_for_index(current_user)
  end

  def archive
    sr = SurveyResponse.find params[:id]
    if sr.survey.can_edit? current_user
      sr.archived = true
      sr.save!
      add_flash :notices, "The Survey Response for #{sr.user.full_name} has been archived."
      redirect_to sr.survey
    else
      error_redirect "You do not have permission to work with this survey."
    end
  end

  def restore
    sr = SurveyResponse.find params[:id]
    if sr.survey.can_edit? current_user
      sr.archived = false
      sr.save!
      add_flash :notices, "The Survey Response for #{sr.user.full_name} has been restored."
      redirect_to sr.survey
    else
      error_redirect "You do not have permission to work with this survey."
    end
  end
  
  #send user invite
  def invite
    sr = SurveyResponse.find params[:id]
    if !sr.can_edit?(current_user) 
      error_redirect "You do not have permission to send invites for this survey."
      return
    end
    sr.invite_user!
    respond_to do |format|
      format.html {
        add_flash :notices, "Invite will be resent to the user at #{sr.user.email}"
        redirect_to sr
      }
      format.json {
        render json: {ok: 'ok'}
      }
    end
  end

end
