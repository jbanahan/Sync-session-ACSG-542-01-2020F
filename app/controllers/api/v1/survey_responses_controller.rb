module Api; module V1; class SurveyResponsesController < Api::V1::ApiController
  include SurveyResponsesControllerSupport

  def index
    if current_user.view_surveys?
      responses = survey_responses_for_index(current_user)

      output = []
      responses.each do |r|
        output << {
          id: r.id,
          name: r.survey.name,
          subtitle: r.subtitle,
          status: r.status,
          checkout_token: checkout_token(r, current_user),
          checkout_by_user: survey_user(r.checkout_by_user),
          checkout_expiration: r.checkout_expiration
        }
      end

      render json: {"results" => output}
    else
      render_forbidden
    end
  end

  def show
    sr = show_survey_response params[:id], current_user
    render json: json_survey_response(sr, current_user)
  end

  def checkout
    sr = checkout_handling(params[:id], params[:checkout_token]) do |sr|
      sr.checkout current_user, params[:checkout_token]
      sr.save!
      sr.survey_response_logs.create!(:message=>"Checked out.",:user_id=>current_user.id)
    end

    render json: json_survey_response(sr, current_user) if sr
  end

  def cancel_checkout
    sr = checkout_handling(params[:id], params[:checkout_token]) do |sr|
      sr.clear_checkout
      sr.save!
      sr.survey_response_logs.create!(:message=>"Check out cancelled.",:user_id=>current_user.id)
    end

    render json: json_survey_response(sr, current_user) if sr
  end

  def checkin
    #TODO Figure out how to handle attachments
    req = params[:survey_response]

    sr = checkout_handling(req.try(:[], 'id'), req.try(:[], 'checkout_token'), true) do |sr|
      # We ONLY want to check in/update data that the survey taker themselves can actually update
      # (This skips such things as ratings and any answer/comments/etc that already have an id).
      sr.name = req[:name]
      sr.address = req[:address]
      sr.phone = req[:phone]
      sr.email = req[:email]
      sr.fax = req[:fax]

      answers = req[:answers]
      if answers.respond_to?(:each)
        answers.each do |a|
          build_answer sr, current_user, a
        end
      end

      save_cap = false
      if req[:corrective_action_plan] && sr.corrective_action_plan && sr.corrective_action_plan.can_view?(current_user) && sr.corrective_action_plan.status == CorrectiveActionPlan::STATUSES[:active]
        update_corrective_action_plan(sr.corrective_action_plan, req[:corrective_action_plan], current_user)
        save_cap = true
      end

      sr.clear_checkout
      sr.save!
      sr.corrective_action_plan.save! if save_cap
      sr.survey_response_logs.create!(:message=>"Checked in.",:user_id=>current_user.id)
      sr.log_update current_user
      if save_cap
        sr.corrective_action_plan.save!
      end
      
    end
    
    render json: json_survey_response(sr, current_user) if sr
  end

  def submit
    sr = find_survey_response params[:id], current_user

    # Only survey takers (.ie can_view?) can submit, raters (can_edit?) 
    # cannot submit
    if !sr.can_view?(current_user)
      render_forbidden "Survey is archived."
      return
    end

    Lock.with_lock_retry(sr) do 
      if submit_survey_response(sr, current_user)
        sr.save!
      else
        render_forbidden sr.errors.full_messages
        return
      end
    end

    render json: json_survey_response(sr, current_user)
  end

  private
    def checkout_handling survey_response_id, checkout_token, checking_in = false
      sr = SurveyResponse.find survey_response_id

      if checkout_token.blank?
        render_error "No checkout_token received."
        return
      end

      if !sr.can_view?(current_user)
        render_forbidden
        return
      end

      if sr.archived? || sr.survey.archived?
        render_forbidden "Survey is archived."
        return
      end

      Lock.with_lock_retry(sr) do
        if sr.checkout_by_user && sr.checkout_by_user != current_user
          render_forbidden "Survey is checked out by another user."
          return
        else
          # Handle cases where you're trying to checkin a survey that has its checkout expired
          if checking_in && sr.checkout_by_user.nil?
            render_forbidden "The survey checkout has expired.  Check out the survey again before checking it back in."
            return
          elsif sr.checkout_token && sr.checkout_token != checkout_token
            render_forbidden "Survey is checked out to you on another device."
            return
          end
        end

        yield sr

      end

      sr
    end

    def build_answer sr, user, json
      # Validate the choice supplied is valid
      question = Question.where(id: json[:question_id], survey_id: sr.survey.id).first

      # Raise an error if this is invalid..it shouldn't happen and basiclly indicates someone
      # is messing w/ the request or bad programming..either way it should raise.
      raise StatusableError.new("Invalid Question responded to.", :internal_server_error) if question.nil?

      choices = question.choice_list

      # Just flat out raise an error if the choice given is invalid...this should
      # never happen unless someone's tampering w/ the response.

      # Leaving an answer blank is ok too
      raise StatusableError.new("Invalid Answer of '#{json[:choice]}' given for question id #{json[:question_id]}.", :internal_server_error) unless choices.include?(json[:choice]) || json[:choice].blank?

      if json[:id]
        answer = sr.answers.find {|a| a.id }
        raise StatusableError.new("Attempted to update an answer that does not exist.", :internal_server_error) unless answer
      else
        answer = sr.answers.build question: question
      end

      answer.choice = json[:choice]
      
      comments = json[:answer_comments]
      # Only bother adding comments that do not have ids..you can't update existing comments.
      if comments && comments.respond_to?(:each)
        comments.each do |comment|
          next unless comment[:id].nil?

          answer.answer_comments.build content: comment[:content], user: user
        end
      end

      answer
    end

    def update_corrective_action_plan cap, req, user
      # caps can have comments, only create these...user can't update comments
      Array.wrap(req[:comments]).each do |com|
        next unless com[:id].blank?

        cap.comments.build body: com[:body], user: user
      end

      # caps can have corrective issues, only update the action_taken on these.  This is
      # the only portion of the issue the survey taker can update.
      Array.wrap(req[:corrective_issues]).each do |iss|
        # There are never new issues added by the end-user..
        issue = cap.corrective_issues.find {|i| i.id == iss['id'].to_i}
        next unless issue

        issue.action_taken = iss[:action_taken]
      end

    end

end; end; end
