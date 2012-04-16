class SupportTicketsController < ApplicationController

  def index 
    @tickets = SupportTicket.where(:requestor_id=>current_user.id).order("state DESC")
    if current_user.support_agent?
      @assigned = SupportTicket.open.where(:agent_id=>current_user.id)
      @unassigned = SupportTicket.open.where(:agent_id=>nil)
      @open_assigned_to_others = SupportTicket.open.where("agent_id != ?",current_user.id)
    end
  end
  
  def new
    @ticket = current_user.support_agent? ? SupportTicket.new(:agent=>current_user) : SupportTicket.new(:requestor=>current_user) 
    @ticket.last_saved_by = current_user
    @ticket.email_notifications = true
    @ticket.state = "Open"
  end

  def create
    t = SupportTicket.create(params[:support_ticket])
    if t.errors.blank?
      add_flash :notices, "Ticket saved successfully, a support agent has been notified."
      redirect_to support_tickets_path
    else 
      errors_to_flash t, :now=>true
      @ticket = t
      render :new
    end
  end

  def edit
    @ticket = SupportTicket.find params[:id]
    error_redirect request.referrer unless current_user.support_agent? || @ticket.requestor == current_user
  end

  def update
    t = SupportTicket.find params[:id]
    p = params[:support_ticket].clone
    p[:last_saved_by_id] = current_user.id
    t.update_attributes(p)
    if t.errors.blank?
      add_flash :notices, "Ticket saved successfully, a support agent has been notified."
      redirect_to support_tickets_path
    else 
      errors_to_flash t, :now=>true
      @ticket = t
      render :edit
    end
  end

  def show
    redirect_to edit_support_ticket_path(params[:id])
  end
end
