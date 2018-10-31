module Api; module V1; class FeedbackController < Api::V1::ApiController

  def send_feedback
    OpenMailer.delay.send_feedback(current_user, params[:message], params[:url])

    render json: {'ok'=>'ok'}
  end

end; end; end;