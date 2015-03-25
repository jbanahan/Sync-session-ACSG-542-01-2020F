class SurveyResponsesController < ApplicationController
  def show
    @sr = SurveyResponse.find params[:id]
    if !@sr.can_view?(current_user) && !@sr.can_edit?(current_user)
      error_redirect "You do not have permission to work with this survey."
      return
    end
    if @sr.assigned_to_user? current_user
      if @sr.response_opened_date.nil?
        @sr.response_opened_date = 0.seconds.ago 
        @sr.save
      end
      @respond_mode = true unless @sr.submitted_date
    elsif @sr.submitted_date && @sr.can_edit?(current_user) 
      @rate_mode = true
    end
    archived = (@sr.archived? || @sr.survey.archived?)
    respond_to do |format|
      format.html {
        if old_ie_version? 
          add_flash :errors, "You are using an unsupported version of Internet Explorer.  Upgrade to at least version 9 or consider using Google Chrome before filling in any survey answers.", now: true
        end
        
        @no_action_bar = true
      }

      format.json { 
        h = @sr.as_json(include: [
          {answers:{methods:[:hours_since_last_update],include: {
            question:{methods:[:html_content,:choice_list], only:[:id,:warning, :require_comment, :require_attachment],include:{attachments:{only:[:id,:attached_file_name]}}},
            answer_comments:{only:[:content,:private,:created_at],include:[{user:{only:[:id],methods:[:full_name]}}]}
          }}},
          {survey:{only:[:id,:name],methods:[:rating_values]}}
        ])
        h['survey_response']['archived'] = archived
        h['survey_response']['can_rate'] = !archived && @rate_mode
        h['survey_response']['can_answer'] = !archived && @respond_mode
        h['survey_response']['can_submit'] = !archived && @respond_mode && @sr.submitted_date.blank?
        h['survey_response']['can_make_private_comment'] = !archived && @sr.can_edit?(current_user)
        h['survey_response'][:answers].each_with_index do |a,i| 
          a['sort_number'] = (i+1)
          if a[:answer_comments] && !@sr.can_edit?(current_user)
            a[:answer_comments].delete_if {|ac| ac['private']}
          end
          a[:attachments] = Attachment.attachments_as_json(Answer.find(a['id']))[:attachments]
        end

        # In order to do some validation that questions requiring comments actually have 
        # comments made by the survey takers, we need to know the full list of survey takers
        # and check against those.  Another means of attacking this would be to denote via a method at the 
        # answer comment level if the comment was by a survey taker or not.  This approach seems easier though.
        survey_takers = []
        if @sr.user
          survey_takers << @sr.user.id
        else
          survey_takers.push *@sr.group.users.collect(&:id)
        end
        h['survey_response']['survey_takers'] = survey_takers
        
        render json: h
      }
    end
  end
  
  def update
    sr = SurveyResponse.find params[:id]
    if !sr.can_view?(current_user) && !sr.can_edit?(current_user)
      error_redirect "You do not have permission to work with this survey."
      return
    end
    log_message = "Response saved."
    if sr.assigned_to_user? current_user
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
    if old_ie_version? 
      add_flash :errors, "You are using an unsupported version of Internet Explorer.  Upgrade to at least version 9 or consider using Google Chrome before filling in any survey answers.", now: true
    end
    @survey_responses = SurveyResponse.where("user_id = ? OR group_id IN (?)", current_user.id, current_user.groups.map(&:id)).joins(:survey).where(surveys: {archived: false}).merge(SurveyResponse.was_archived(false))
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
