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
          checkout_token:nil,
          checkout_to_user: nil,
          checkout_expiration: nil
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

end; end; end