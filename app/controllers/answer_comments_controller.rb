class AnswerCommentsController < ApplicationController 
  def create
    answer = Answer.find(params[:answer_id])
    sr = answer.survey_response
    raise ActionController::RoutingError.new('Not Found') unless sr.can_view?(current_user)
    ac = answer.answer_comments.create!(:user_id=>current_user.id,
      :private=>(sr.can_edit?(current_user) ? params['comment']['private'] : false),
      :content=>params['comment']['content']
    )
    render json: ac.to_json(:include=>{:user=>{:only=>[:id],:methods=>[:full_name]}})
  end
end
