require 'open_chain/workflow_processor'

module Api; module V1; class CommentsController < Api::V1::ApiController
  def for_module
    r = {comments:[]}
    obj = base_object params, :module_type, :id
    raise StatusableError.new("You do not have permission to view these comments.",401) unless obj.can_view?(current_user)
    obj.comments.each {|c| r[:comments] << comment_json(c)}
    render json: r
  end

  def create
    obj = base_object params[:comment], :commentable_type, :commentable_id
    raise StatusableError.new("You do not have permission to add a comment.",401) unless obj.can_comment?(current_user)
    my_params = params[:comment]
    my_params[:user_id] = current_user.id
    c = Comment.create!(my_params)
    OpenChain::WorkflowProcessor.async_process(c.commentable)
    render json: {comment:comment_json(c)}
  end

  def destroy
    c = Comment.find params[:id]
    raise StatusableError.new("You cannot delete a comment that another user created.",401) unless c.user == current_user || current_user.sys_admin?
    raise StatusableError.new(c.errors.full_messages.join("\n")) unless c.destroy
    OpenChain::WorkflowProcessor.async_process(c.commentable)
    render json: {message:'Comment deleted'}
  end

  private
  def comment_json c
    h = {id:c.id,commentable_type:c.commentable_type,commentable_id:c.commentable_id,
        user:{id:c.user.id,full_name:c.user.full_name,email:c.user.email},
        subject:c.subject,body:c.body,created_at:c.created_at,permissions:render_permissions(c)
      }
    h
  end

  def render_permissions c
    {
      can_view:c.can_view?(current_user),
      can_edit:c.can_edit?(current_user),
      can_delete:c.can_delete?(current_user)
    }
  end

  def base_object params_base, module_type_param, id_param
    cm = CoreModule.find_by_class_name params_base[module_type_param]
    raise StatusableError.new("Module #{params_base[module_type_param]} not found.",404) unless cm
    r = cm.klass.where(id:params_base[id_param]).includes(:comments).first
    raise StatusableError.new("#{cm.label} with id #{params_base[id_param]} not found.",404) unless r
    r
  end
end; end; end