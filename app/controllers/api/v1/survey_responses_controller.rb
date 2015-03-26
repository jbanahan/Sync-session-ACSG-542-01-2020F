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
    sr = SurveyResponse.find params[:id]
    checkout_token = params[:checkout_token]

    if checkout_token.blank?
      render_error "No checkout_token received."
      return
    end

    if !sr.assigned_to_user? current_user
      render_forbidden
      return
    end

    Lock.with_lock_retry(sr) do 
      if sr.checkout_by_user && sr.checkout_by_user != current_user
        render_forbidden "Survey is already checked out by another user."
        return
      else
        if sr.checkout_by_user && sr.checkout_token && sr.checkout_token != checkout_token
          render_forbidden "Survey is already checked out to you on another device."
          return
        end
      end

      sr.checkout_by_user = current_user
      sr.checkout_token = checkout_token
      sr.checkout_expiration = Time.zone.now + 2.days

      sr.save!
    end

    sr = show_survey_response params[:id], current_user
    render json: json_survey_response(sr, current_user)
  end

end; end; end