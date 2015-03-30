module SurveyResponsesControllerSupport

  def survey_responses_for_index user
    SurveyResponse.where("user_id = ? OR group_id IN (?)", user.id, user.groups.map(&:id)).joins(:survey).where(surveys: {archived: false}).merge(SurveyResponse.was_archived(false))
  end

  def find_survey_response id, current_user
    sr = SurveyResponse.find id

    if !sr.can_view?(current_user) && !sr.can_edit?(current_user)
      raise StatusableError, "You do not have permission to work with this survey."
    end

    sr
  end

  def show_survey_response id, current_user
    sr = find_survey_response(id, current_user)

    if sr.assigned_to_user?(current_user) && sr.response_opened_date.nil?
      sr.response_opened_date = Time.zone.now
      sr.save
    end

    sr
  end

  def rate_mode? sr, user
    if sr.assigned_to_user? user
      return false
    else
      return sr.submitted_date && sr.can_edit?(current_user) 
    end
  end

  def respond_mode? sr, user
    if sr.assigned_to_user? user
      return sr.submitted_date.blank?
    else
      return false
    end
  end

  def checkout_token sr, user
    (sr.checkout_by_user == user ? sr.checkout_token : nil) 
  end

  def survey_user user
    user.nil? ? nil : {'id' => user.id, 'username' => user.username, 'full_name' => user.full_name}
  end

  def json_survey_response sr, user
    rate_mode = rate_mode?(sr, user)
    respond_mode = respond_mode?(sr, user)
    archived = sr.archived? || sr.survey.archived?

    h = sr.as_json(include: [
        {answers:{methods:[:hours_since_last_update],include: {
          question:{methods:[:html_content,:choice_list], only:[:id,:warning, :require_comment, :require_attachment],include:{attachments:{only:[:id,:attached_file_name]}}},
          answer_comments:{only:[:id,:content,:private,:created_at],include:[{user:{only:[:id, :username],methods:[:full_name]}}]}
        }}},
        {survey:{only:[:id,:name],methods:[:rating_values]}}
      ])
    # Since the web doesn't have support for checking out survey's...if we encounter a survey that's been checked out...just
    # treat it like it's read only...even if the user that checked out the survey is the one attempting to view it.  Since they
    # didn't check out the survey via their web browser.
    h['survey_response']['archived'] = archived
    h['survey_response']['can_rate'] = !archived && rate_mode?(sr, user) && sr.checkout_by_user.nil?
    h['survey_response']['can_answer'] = !archived && respond_mode?(sr, user) && sr.checkout_by_user.nil?
    h['survey_response']['can_submit'] = !archived && respond_mode && sr.submitted_date.blank? && sr.checkout_by_user.nil?
    h['survey_response']['can_comment'] = sr.checkout_by_user.nil?
    h['survey_response']['can_make_private_comment'] = !archived && sr.can_edit?(user) && sr.checkout_by_user.nil?
    h['survey_response'][:answers].each_with_index do |a,i| 
      a['sort_number'] = (i+1)
      if a[:answer_comments] && !sr.can_edit?(user)
        a[:answer_comments].delete_if {|ac| ac['private']}
      end
      a[:attachments] = Attachment.attachments_as_json(Answer.find(a['id']))[:attachments]
    end

    # In order to do some validation that questions requiring comments actually have 
    # comments made by the survey takers, we need to know the full list of survey takers
    # and check against those.  Another means of attacking this would be to denote via a method at the 
    # answer comment level if the comment was by a survey taker or not.  This approach seems easier though.
    survey_takers = []
    if sr.user
      survey_takers << sr.user.id
    else
      survey_takers.push *sr.group.users.collect(&:id)
    end
    h['survey_response']['survey_takers'] = survey_takers

    h['survey_response']['checkout_by_user'] = nil
    if sr.checkout_by_user
      h['survey_response']['checkout_by_user'] = survey_user(sr.checkout_by_user)
    end
    h['survey_response']['checkout_expiration'] = sr.checkout_expiration
    h['survey_response']['checkout_token'] = checkout_token(sr, user)

    h
  end


end