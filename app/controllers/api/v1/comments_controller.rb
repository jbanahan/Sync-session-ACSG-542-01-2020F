require 'open_chain/api/v1/comment_api_json_generator'

module Api; module V1; class CommentsController < Api::V1::ApiCoreModuleControllerBase
  include PolymorphicFinders

  def for_module
    r = {comments: []}
    obj = base_object params, :module_type, :id
    raise StatusableError.new("You do not have permission to view these comments.", 401) unless obj.can_view?(current_user)
    obj.comments.each {|c| r[:comments] << comment_json(c)}
    render json: r
  end

  def create
    obj = base_object params[:comment], :commentable_type, :commentable_id
    raise StatusableError.new("You do not have permission to add a comment.", 401) unless obj.can_comment?(current_user)
    c = Comment.new(permitted_params(params))
    c.user = current_user
    c.save!
    render json: {comment: comment_json(c)}
  end

  def destroy
    c = Comment.find params[:id]
    raise StatusableError.new("You cannot delete a comment that another user created.", 401) unless c.user == current_user || current_user.sys_admin?
    raise StatusableError, c.errors.full_messages.join("\n") unless c.destroy
    render json: {message: 'Comment deleted'}
  end

  # The polymorphic actions below are all mapped to routes like
  # object_type/object_id/comments/comment_id (.ie orders/1/comments/200)
  # They all handle and respond with json structured using model fields as json key names
  # as opposed to the other methods here using the comment_json below.
  def polymorphic_index
    find_object(params, current_user) do |obj|
      json = []
      obj.comments.each do |comment|
        json << obj_to_json_hash(comment)
      end

      render json: {"comments" => json}
    end
  end

  def polymorphic_show
    find_object(params, current_user) do |obj|
      comment = obj.comments.find {|c| c.id == params[:id].to_i }
      if comment&.can_view?(current_user)
        render json: {"comment" => obj_to_json_hash(comment)}
      else
        render_forbidden
      end
    end
  end

  def polymorphic_create
    edit_object(params, current_user) do |obj|
      comment = obj.comments.build
      comment.user = current_user
      save_comment(current_user, comment, params[:comment])
    end
  end

  def polymorphic_destroy
    edit_object(params, current_user) do |obj|
      comment = obj.comments.find {|c| c.id == params[:id].to_i }
      if comment && comment.user == current_user
        comment.destroy
        obj.create_async_snapshot(current_user) if obj.respond_to?(:create_async_snapshot)
        render_ok
      else
        render_forbidden
      end
    end
  end

  def json_generator
    OpenChain::Api::V1::CommentApiJsonGenerator.new
  end

  private

    def comment_json c
      h = {id: c.id, commentable_type: c.commentable_type, commentable_id: c.commentable_id,
           user: {id: c.user.id, full_name: c.user.full_name, email: c.user.email},
           subject: c.subject, body: c.body, created_at: c.created_at, permissions: json_generator.render_permissions(c, current_user)}
      h
    end

    def base_object params_base, module_type_param, id_param
      cm = CoreModule.find_by class_name: params_base[module_type_param]
      raise StatusableError.new("Module #{params_base[module_type_param]} not found.", 404) unless cm
      r = cm.klass.where(id: params_base[id_param]).includes(:comments).first
      raise StatusableError.new("#{cm.label} with id #{params_base[id_param]} not found.", 404) unless r
      r
    end

    def find_object params, user
      obj = polymorphic_find(params[:base_object_type], params[:base_object_id])
      if obj&.can_view?(user)
        yield obj
      else
        render_forbidden
        nil
      end
    end

    def edit_object params, user
      obj = polymorphic_find(params[:base_object_type], params[:base_object_id])
      if obj&.can_comment?(user)
        yield obj
      else
        render_forbidden
        nil
      end
    end

    def save_comment user, comment, params
      all_requested_model_fields(CoreModule::COMMENT).each {|mf| mf.process_import(comment, params[mf.uid], user) unless params[mf.uid].nil? }
      comment.save
      if comment.errors.any?
        render_error comment.errors
      else
        comment.commentable.create_async_snapshot(current_user) if comment.commentable.respond_to?(:create_async_snapshot)
        render json: {"comment" => obj_to_json_hash(comment)}
      end
    end

    def permitted_params(params)
      params.require(:comment).except(:user_id, :commentable).permit(:body, :subject, :commentable_id, :commentable_type)
    end
end; end; end
