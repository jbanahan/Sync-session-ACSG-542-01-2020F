require 'open_chain/trello'
module Api; module V1; class FeedbackController < Api::V1::ApiController
  def send_feedback
    user_id = current_user.id
    message = params[:message]
    url = params[:url]

    OpenChain::Trello.delay.create_feedback_card!(user_id,url,message)

    render json: {'ok'=>'ok'}
  end
end; end; end;