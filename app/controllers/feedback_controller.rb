class FeedbackController < ApplicationController
  skip_before_filter :verify_authenticity_token
  
  def send_feedback
    OpenMailer.send_feedback(current_user, params[:message], nil).deliver_later
  end
end