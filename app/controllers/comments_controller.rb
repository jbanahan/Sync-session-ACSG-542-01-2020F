class CommentsController < ApplicationController
  def create
    cmt = nil
    if cmt = Comment.create(params[:comment])
      commentable = cmt.commentable
      unless commentable.can_edit?(current_user)
        add_flash :errors, "You do not have permission to add comments to this item."
      end
      cmt.user = current_user
      cmt.save
      errors_to_flash cmt 
    end  
    redirect_to commentable
  end
  def destroy
    cmt = Comment.find(params[:id])
    commentable = cmt.commentable
    action_secure((current_user.admin? || current_user.id == cmt.user_id), cmt, {:lock_check => false, :verb => "delete", :module_name => "comment"}) {
      add_flash :notices, "Comment deleted successfully."  if cmt.destroy
      errors_to_flash cmt
    }
    redirect_to commentable
  end
  def update
    cmt = Comment.find(params[:id])
    commentable = cmt.commentable
    action_secure(current_user.id==cmt.user_id, cmt, {:lock_check => false, :verb => "edit", :module_name => "comment"}) {
      add_flash :notices, "Commentu updated successfully." if cmt.update_attributes(params[:comment])
      errors_to_flash cmt
    }
    redirect_to commentable
  end
end
