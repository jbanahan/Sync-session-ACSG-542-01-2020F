class AnswersController < ApplicationController
  def update
    answer = Answer.find params[:id] 
    sr = answer.survey_response
    raise ActionController::RoutingError.new('Not Found') unless sr.can_view?(current_user)
    answer.choice = params[:answer][:choice] if !params[:answer][:choice].nil? && sr.assigned_to_user?(current_user)
    answer.rating = params[:answer][:rating] if !params[:answer][:rating].nil? && sr.can_edit?(current_user)

    # Don't log updates if there aren't any changes to the answer, otherwise we potentially will email
    # out update notifications when nothing truly changed.  This method is called automatically by the front-end.
    if answer.changes.any?
      answer.save!
      answer.log_update current_user
    end
    
    render json: {ok:'ok'}
  end
end
