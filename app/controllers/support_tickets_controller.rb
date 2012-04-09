class SupportTicketsController < ApplicationController

  def index 
    @tickets = SupportTicket.where(:requestor_id=>current_user.id).order("state DESC")
    if current_user.support_agent?
      @assigned = SupportTicket.open.where(:agent_id=>current_user.id)
      @unassigned = SupportTicket.open.where(:agent_id=>nil)
    end
  end
end
