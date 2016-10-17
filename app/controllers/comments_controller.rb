require 'open_chain/workflow_processor'
require 'open_chain/bulk_action/bulk_action_runner'
require 'open_chain/bulk_action/bulk_comment'
require 'open_chain/bulk_action/bulk_action_support'
require 'open_chain/email_validation_support'

class CommentsController < ApplicationController
  include OpenChain::BulkAction::BulkActionSupport
  include OpenChain::EmailValidationSupport

  def create
    cmt = nil
    if cmt = Comment.new(params[:comment])
      commentable = cmt.commentable
      unless commentable.can_comment?(current_user)
        add_flash :errors, "You do not have permission to add comments to this item."
        redirect_to redirect_location(commentable)
        return
      end
      cmt.user = current_user
      if cmt.save
        add_flash :errors, "Email address missing or invalid" unless email(cmt)
      end
      OpenChain::WorkflowProcessor.async_process(commentable)
      errors_to_flash cmt
    end
    redirect_to redirect_location(commentable)
  end
  def destroy
    cmt = Comment.find(params[:id])
    commentable = cmt.commentable
    action_secure((current_user.admin? || current_user.id == cmt.user_id), cmt, {:lock_check => false, :verb => "delete", :module_name => "comment"}) {
      if cmt.destroy
        add_flash :notices, "Comment deleted successfully."
        OpenChain::WorkflowProcessor.async_process(commentable)
      end
      errors_to_flash cmt
    }
    redirect_to redirect_location(commentable)
  end
  def show
    begin
      redirect_to redirect_location(Comment.find(params[:id]).commentable)
    rescue ActiveRecord::RecordNotFound
      error_redirect "The comment you are searching for has been deleted."
    end
  end
  def update
    cmt = Comment.find(params[:id])
    commentable = cmt.commentable
    action_secure(current_user.id==cmt.user_id, cmt, {:lock_check => false, :verb => "edit", :module_name => "comment"}) {
      if cmt.update_attributes(params[:comment])
        add_flash :notices, "Comment updated successfully."
        OpenChain::WorkflowProcessor.async_process(commentable)
        email cmt
      end
      errors_to_flash cmt
    }
    redirect_to redirect_location(commentable)
  end
  def send_email
    cmt = Comment.find(params[:id])
    email_sent = false
    action_secure(cmt.commentable.can_view?(current_user),cmt.commentable, {:lock_check => false, :verb => "work with", :module_name => "item"}) {
      email_sent = email(cmt)
    }
    if email_sent || params[:to].blank?
      render :text=>"OK"
    else 
      render :text=>"Email is invalid."
    end
  end

  def bulk_count
    c = get_bulk_count params[:pk], params[:sr_id]
    render json: {count: c}
  end

  def bulk
    opts = {}
    opts['module_type'] = params['module_type']
    opts['subject'] = params['subject']
    opts['body'] = params['body']
    OpenChain::BulkAction::BulkActionRunner.process_from_parameters current_user, params, OpenChain::BulkAction::BulkComment, opts
    render json: {'ok'=>'ok'}
  end

private
  def email cmt
    to = params[:to]
    if email_list_valid?(to)
      OpenMailer.delay.send_comment(current_user,to,cmt,comment_url(cmt))
      true
    else
      false
    end
  end

  def redirect_location commentable
    params[:redirect_to].blank? ? commentable : params[:redirect_to]
  end

end
