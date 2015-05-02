require 'open_chain/workflow_processor'

class CommentsController < ApplicationController
  def create
    cmt = nil
    if cmt = Comment.create(params[:comment])
      commentable = cmt.commentable
      unless commentable.can_comment?(current_user)
        add_flash :errors, "You do not have permission to add comments to this item."
        redirect_to redirect_location(commentable)
        return
      end
      cmt.user = current_user
      if cmt.save
        email cmt
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
    action_secure(cmt.commentable.can_view?(current_user),cmt.commentable, {:lock_check => false, :verb => "work with", :module_name => "item"}) {
      email cmt
    }
    render :text=>"OK"
  end

private
  def email cmt
    to = params[:to]
    unless to.blank?
      OpenMailer.delay.send_comment(current_user,to,cmt,comment_url(cmt))
    end
  end

  def redirect_location commentable
    params[:redirect_to].blank? ? commentable : params[:redirect_to]
  end

end
