require 'open_chain/bulk_action/bulk_action_runner'
require 'open_chain/bulk_action/bulk_comment'
require 'open_chain/bulk_action/bulk_action_support'
require 'open_chain/email_validation_support'

class CommentsController < ApplicationController
  include OpenChain::BulkAction::BulkActionSupport
  include OpenChain::EmailValidationSupport

  def create
    if (cmt = Comment.new(permitted_params(params)))
      commentable = cmt.commentable
      unless commentable.can_comment?(current_user)
        add_flash :errors, "You do not have permission to add comments to this item."
        redirect_to redirect_location(commentable)
        return
      end
      cmt.user = current_user
      if cmt.save
        add_flash :errors, "Email address is invalid." unless params[:to].empty? || email(cmt)
      end
      errors_to_flash cmt
    end
    redirect_to redirect_location(commentable)
  end

  def destroy
    cmt = Comment.find(params[:id])
    commentable = cmt.commentable
    action_secure((current_user.admin? || current_user.id == cmt.user_id), cmt, {lock_check: false, verb: "delete", module_name: "comment"}) do
      if cmt.destroy
        add_flash :notices, "Comment deleted successfully."
      end
      errors_to_flash cmt
    end
    redirect_to redirect_location(commentable)
  end

  def show
      redirect_to redirect_location(Comment.find(params[:id]).commentable)
  rescue ActiveRecord::RecordNotFound
      error_redirect "The comment you are searching for has been deleted."
  end

  def update
    cmt = Comment.find(params[:id])
    commentable = cmt.commentable
    action_secure(current_user.id == cmt.user_id, cmt, {lock_check: false, verb: "edit", module_name: "comment"}) do
      if cmt.update(permitted_params(params))
        add_flash :notices, "Comment updated successfully."
        email cmt
      end
      errors_to_flash cmt
    end
    redirect_to redirect_location(commentable)
  end

  def send_email
    cmt = Comment.find(params[:id])
    email_sent = false
    action_secure(cmt.commentable.can_view?(current_user), cmt.commentable, {lock_check: false, verb: "work with", module_name: "item"}) do
      email_sent = email(cmt)
    end
    if email_sent || params[:to].blank?
      render html: "OK"
    else
      render html: "Email is invalid."
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
    render json: {'ok' => 'ok'}
  end

  private

  def email cmt
    to = params[:to]
    if email_list_valid?(to)
      OpenMailer.send_comment(current_user, to, cmt, comment_url(cmt)).deliver_later
      true
    else
      false
    end
  end

  def redirect_location commentable
    params[:redirect_to].presence || commentable
  end

  def permitted_params(params)
    params.require(:comment).except(:user_id, :commentable).permit(:body, :subject, :commentable_id, :commentable_type)
  end
end
