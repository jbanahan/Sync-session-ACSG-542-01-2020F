module Api; module V1;  class SupportRequestsController < Api::V1::ApiController

  def create
    sr = params[:support_request]

    r = SupportRequest.new user: current_user, body: sr[:body], severity: sr[:importance], referrer_url: request.referrer
    valid = false
    SupportRequest.transaction do
      # Normally, we'd want to do this outside the request cycle, however, since the response needs to indicate if the 
      # ticket posted to the external system, then we need to wait on the actual response from the external system.

      # Send ticket should raise if the ticket doesn't get created, putting this in a transaction ensures we
      # don't get into a state where the ticket is in our system but not in the remote one.
      valid = r.save && r.send_request!
    end

    if valid
      render json: {support_request_response: {
        ticket_number: r.ticket_number
      }
    }
    else
      render_error r.errors
    end
  end

end; end; end;