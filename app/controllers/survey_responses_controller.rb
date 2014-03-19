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
    elsif @sr.submitted_date && @sr.can_edit?(current_user) 
      @rate_mode = true
    end
    respond_to do |format|
      format.html {
        @no_action_bar = true
      }

      format.json { 
        h = @sr.as_json(include: [
          {answers:{methods:[:hours_since_last_update],include: {
            question:{methods:[:html_content,:choice_list], only:[:id,:warning],include:{attachments:{only:[:id,:attached_file_name]}}},
            answer_comments:{only:[:content,:private,:created_at],include:[{user:{only:[:id],methods:[:full_name]}}]}
          }}},
          {survey:{only:[:id,:name],methods:[:rating_values]}},
          {user:{only:[:id],methods:[:full_name]}}
        ])
        h['survey_response']['can_rate'] = @rate_mode
        h['survey_response']['can_answer'] = @respond_mode
        h['survey_response']['can_submit'] = @respond_mode && @sr.submitted_date.blank?
        h['survey_response']['can_make_private_comment'] = @sr.can_edit?(current_user)
        h['survey_response'][:answers].each_with_index do |a,i| 
          a['sort_number'] = (i+1)
          if a[:answer_comments] && !@sr.can_edit?(current_user)
            a[:answer_comments].delete_if {|ac| ac['private']}
          end
          a[:attachments] = Attachment.attachments_as_json(Answer.find(a['id']))[:attachments]
        end
        
        render json: h
      }
    end
  end
  
  def update
    sr = SurveyResponse.find params[:id]
    if sr.survey.company_id!=current_user.company_id && sr.user!=current_user
      error_redirect "You do not have permission to work with this survey."
      return
    end
    log_message = "Response saved."
    if sr.user==current_user
      if params[:do_submit]
        sr.submitted_date = 0.seconds.ago 
        sr.save!
        log_message = "Response submitted."
      end
    end
    sr.update_attributes params[:survey_response] unless params[:survey_response].blank?
    sr.survey_response_logs.create!(:message=>log_message,:user_id=>current_user.id)
    sr.log_update current_user
    add_flash :notices, "Response saved successfully."
    respond_to do |format|
      format.html {redirect_to sr}
      format.json {render json: {ok:'ok'}}
    end
    
  end

  def index
    @survey_responses = SurveyResponse.where(:user_id=>current_user.id)
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
