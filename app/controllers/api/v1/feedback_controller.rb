module Api; module V1; class FeedbackController < Api::V1::ApiController

  def send_feedback
    OpenMailer.send_feedback(current_user, params[:message], params[:url]).deliver_later

    render json: {'ok'=>'ok'}
  end

end; end; end;