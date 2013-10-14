class AnswersController < ApplicationController
  def update
    answer = Answer.find params[:id] 
    sr = answer.survey_response
    raise ActionController::RoutingError.new('Not Found') unless sr.can_view?(current_user)
    answer.choice = params[:answer][:choice] if sr.user == current_user
    answer.rating = params[:answer][:rating] if sr.can_edit?(current_user)
    answer.save!
    render json: {ok:'ok'}
  end
end
