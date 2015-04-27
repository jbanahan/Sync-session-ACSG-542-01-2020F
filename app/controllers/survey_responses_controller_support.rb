module SurveyResponsesControllerSupport

  def survey_responses_for_index user
    responses = SurveyResponse.where("user_id = ? OR group_id IN (?)", user.id, user.groups.map(&:id)).joins(:survey).where(surveys: {archived: false}).merge(SurveyResponse.was_archived(false)).readonly(false)
    responses.each do |resp|
      handle_checkout_expiration resp
    end

    responses
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

    handle_checkout_expiration sr
    
    sr
  end

  def handle_checkout_expiration resp
    # Clear any checkout information if it's out-dated
    if resp.checkout_expiration && resp.checkout_expiration < Time.zone.now
      resp.clear_checkout
      resp.save!
    end
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
          question:{methods:[:html_content,:choice_list, :require_comment_for_choices, :require_attachment_for_choices], only:[:id,:warning, :require_comment, :require_attachment]},
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
    h['survey_response']['can_comment'] = !archived && sr.checkout_by_user.nil?
    h['survey_response']['can_make_private_comment'] = !archived && sr.can_edit?(user) && sr.checkout_by_user.nil?
    h['survey_response'][:answers].each_with_index do |a, i| 
      a['sort_number'] = (i+1)
      if a[:answer_comments] && !sr.can_edit?(user)
        a[:answer_comments].delete_if {|ac| ac['private']}
      end

      answer = sr.answers.find {|ans| a['id'].to_i == ans.id}
      a[:attachments] = Attachment.attachments_as_json(answer)[:attachments] unless answer.nil?
      a[:question][:attachments] = Attachment.attachments_as_json(answer.question)[:attachments] unless a[:question].nil? || answer.nil? || answer.question.nil?
    end

    # In order to do some validation that questions requiring comments actually have 
    # comments made by the survey takers, we need to know the full list of survey takers
    # and check against those.  Another means of attacking this would be to denote via a method at the 
    # answer comment level if the comment was by a survey taker or not.  This approach seems easier though.
    h['survey_response']['survey_takers'] = survey_takers(sr).collect(&:id)
    h['survey_response']['checkout_by_user'] = nil
    if sr.checkout_by_user
      h['survey_response']['checkout_by_user'] = survey_user(sr.checkout_by_user)
    end
    h['survey_response']['checkout_expiration'] = sr.checkout_expiration
    h['survey_response']['checkout_token'] = checkout_token(sr, user)

    if sr.corrective_action_plan
      cap = corrective_action_plan_json(sr.corrective_action_plan, user)
      h['survey_response']['corrective_action_plan'] = cap['corrective_action_plan']
      h['survey_response']['corrective_action_plan']['can_edit'] = cap['can_edit']
      h['survey_response']['corrective_action_plan']['can_update_actions'] = cap['can_update_actions']
    end
    h.with_indifferent_access
  end

  def corrective_action_plan_json cap, user
    j = cap.as_json(
      only: [:id, :status],
      include:{
        corrective_issues: {
          only: [:id, :description, :suggested_action, :action_taken, :resolved],
          methods:[:html_description,:html_suggested_action,:html_action_taken]
        },
        comments: {
          only: [:id, :body],
          methods:[:html_body],
          include:{
            user:{
              only:[:id, :username],
              methods:[:full_name]
            }
          }
        }
      }
    )
    j[:can_edit] = (cap.can_edit?(user) && cap.status!=CorrectiveActionPlan::STATUSES[:resolved])
    j[:can_update_actions] = (cap.can_update_actions?(user) && cap.status == CorrectiveActionPlan::STATUSES[:active])
    j["corrective_action_plan"][:corrective_issues].each do |ci|
      issue = cap.corrective_issues.find {|iss| ci['id'].to_i == iss.id}
      ci[:attachments] = Attachment.attachments_as_json(issue)[:attachments] unless issue.nil?
    end


    j.with_indifferent_access
  end

  def submit_survey_response survey_response, user
    errors = validate_submitted_response survey_response, user
    
    if errors.blank?
      survey_response.submitted_date = Time.zone.now
      survey_response.survey_response_logs.create! message: "Response submitted.", user: user
      survey_response.log_update user
    else
      survey_response.errors[:base].push *errors
    end

    errors.blank?
  end

  private
    def survey_takers sr
      survey_takers = []
      if sr.user
        survey_takers << sr.user
      else
        survey_takers.push *sr.group.users
      end

      survey_takers
    end

    def validate_submitted_response sr, user
      # Ensure all required questions are answered by the persons required to do so
      # (.ie if question requires comment/attachment, the a comment/attachment must be 
      # present by a survey taker user)

      # Name, Address, Phone, Email must all be present
      errors = []
      errors << "Archived surveys cannot be submitted." if sr.archived?
      errors << "Rated surveys cannot be submitted." if sr.rated?
      errors << "Expired surveys cannot be submitted." if sr.expiration_notification_sent_at && sr.expiration_notification_sent_at < Time.zone.now
      errors << "Checked out surveys cannot be submitted." unless sr.checkout_token.blank?
      errors << "Submitted surveys cannot be submitted." if sr.submitted_date
      errors << "Name, Address, Phone, and Email must all be filled in." if sr.name.blank? || sr.address.blank? || sr.phone.blank? || sr.email.blank?

      takers = survey_takers sr

      sr.answers.each do |a|
        validate_answer(takers, a, errors)
      end

      errors
    end

    def validate_answer survey_takers, a, errors
      q = a.question
      choice = a.choice.to_s.strip

      # This would only happen if someone's messing w/ json, the client/screen should only allow the user
      # to pick valid choices
      if !q.choice_list.blank? && !choice.blank?
        return "Question ##{q.rank} has an invalid answer" unless q.choice_list.include?(choice)
      end

      requires_multiple_choice_answer = q.warning && !q.choice_list.blank?
      requires_comment = (q.warning && q.choice_list.blank?) || q.require_comment || q.require_comment_for_choices.include?(choice)
      requires_attachment = q.require_attachment || q.require_attachment_for_choices.include?(choice)

      missing_answer = requires_multiple_choice_answer && a.choice.blank?
      missing_user_comments = requires_comment && a.answer_comments.find {|c| survey_takers.include? c.user}.nil?
      missing_attachment = requires_attachment && a.attachments.find {|att| survey_takers.include? att.uploaded_by}.nil?

      error = nil

      # Technically, there can be more than one issue w/ an answer.  You can error requiring a choice, requiring a comment and an attachemnt.
      # So make sure we list everything that might be wrong.
      if missing_answer || missing_user_comments || missing_attachment
        error = "Question ##{q.rank + 1} is a required question."

        error << " You must provide an answer." if missing_answer
        error << " You must provide a comment." if missing_user_comments
        error << " You must provide an attachment." if missing_attachment
      end

      errors << error unless error.blank?
      error.blank?
    end
end