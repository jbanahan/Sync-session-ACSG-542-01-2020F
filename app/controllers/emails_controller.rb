class EmailsController < ApplicationController
  skip_before_filter :verify_authenticity_token, :only=>[:postmark_receive]
  skip_before_filter :require_user, :only=>[:postmark_receive]
  def show
    e = Email.find(params[:id])
    action_secure e.can_view?(current_user), e,{:lock_check=>false,:module_name=>"email",:verb=>"edit"} do
      @email = e
    end
  end
  def assign
    r = {"OK"=>"OK"}
    u = User.find params[:user_id]
    emails = Email.where("id IN (?)",params[:email].values.collect {|v| v[:id]})
    if can_edit_all? emails 
      error_msg = nil
      emails.each {|e| error_msg = "Messages cannot be assigned because #{u.full_name} does not have permission to view them." if error_msg.nil? && !e.can_view?(u)}
      if error_msg
        r = {"errors"=>[error_msg]}
      else
        emails.each {|e| e.update_attributes(:assigned_to_id=>u.id)} 
      end
    else
      r = {"errors"=>["You do not have permission to edit these messages."]}
    end
    render :json=>r
  end
  def postmark_receive
    Email.delay.create_from_postmark_json! request.body.read.to_s 
    render :nothing=>true
  end
  def toggle_archive
    r = {"OK"=>"OK"}
    emails = Email.where("id IN (?)",params[:email].values.collect {|v| v[:id]})
    if can_edit_all? emails
      emails.each {|e| e.update_attributes(:archived=>!e.archived?)}
    else
      r = {"errors"=>["You do not have permission to edit these messages."]}
    end
    render :json=>r
  end

  private
  def can_edit_all? emails
    r = true
    emails.each do |e| 
      if !e.can_edit? current_user
        r = false
        break
      end
    end
    r
  end
end
