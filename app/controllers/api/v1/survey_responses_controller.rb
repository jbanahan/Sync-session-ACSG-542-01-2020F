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
      sr.checkout_by_user = current_user
      sr.checkout_token = params[:checkout_token]
      sr.checkout_expiration = Time.zone.now + 2.days

      sr.save!
    end

    render json: json_survey_response(sr, current_user) if sr
  end

  def cancel_checkout
    sr = checkout_handling(params[:id], params[:checkout_token]) do |sr|
      remove_checkout_info sr
      sr.save!
    end

    render json: json_survey_response(sr, current_user) if sr
  end

  def checkin
    #TODO Figure out how to handle attachments
    req = params[:survey_response]

    sr = checkout_handling(req.try(:[], 'id'), req.try(:[], 'checkout_token')) do |sr|
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

      remove_checkout_info sr

      sr.save!
    end
    
    render json: json_survey_response(sr, current_user) if sr
  end


  private
    def checkout_handling survey_response_id, checkout_token
      sr = SurveyResponse.find survey_response_id

      if checkout_token.blank?
        render_error "No checkout_token received."
        return
      end

      if !sr.can_view?(current_user)
        render_forbidden
        return
      end

      Lock.with_lock_retry(sr) do 
        if sr.checkout_by_user && sr.checkout_by_user != current_user
          render_forbidden "Survey is checked out by another user."
          return
        else
          if sr.checkout_by_user && sr.checkout_token && sr.checkout_token != checkout_token
            render_forbidden "Survey is checked out to you on another device."
            return
          end
        end

        yield sr

      end

      sr
    end

    def remove_checkout_info sr
      sr.checkout_by_user = nil
      sr.checkout_token = nil
      sr.checkout_expiration = nil
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

end; end; end