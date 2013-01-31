class EmailsController < ApplicationController
  skip_before_filter :verify_authenticity_token, :only=>[:postmark_receive]
  def show
    e = Email.find(params[:id])
    action_secure e.can_view?(current_user), e,{:lock_check=>false,:module_name=>"email",:verb=>"edit"} do
      @email = e
    end
  end
  def assign
    r = {"OK"=>"OK"}
    u = User.find params[:user_id]
    emails = params[:email].values.collect {|v| Email.find v[:id]}
    secure = true
    #TODO: write security check here
    if secure
      emails.each {|e| e.update_attributes(:assigned_to_id=>u.id)}
    else
      r = {"errors"=>["You do not have permssion to edit these messages."]}
    end
    render :json=>r
  end
  def postmark_receive
    Email.delay.create_from_postmark_json! request.body.read 
    render :nothing=>true
  end
  def toggle_archive
    r = {"OK"=>"OK"}
    email = Email.find params[:id]
    if email.can_edit? current_user
      email.update_attributes(:archived=>!email.archived?)
    else
      r = {"errors"=>["You do not have permssion to edit this message."]}
    end
    render :json=>r
  end
end
