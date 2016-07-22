require 'open_chain/api/descriptor_based_api_entity_jsonizer'

module Api; module V1; class FoldersController < Api::V1::ApiController
  include PolymorphicFinders
  include Api::V1::ApiJsonSupport

  def initialize
    super(OpenChain::Api::DescriptorBasedApiEntityJsonizer.new)
  end

  def index
    find_object(params, current_user) do |obj|
      folders = obj.folders.select {|f| f.can_view?(current_user)}
      json = []
      folders.each do |folder|
        json << folder_view(current_user, folder)
      end

      render json: {"folders" => json}
    end
  end

  def create
    edit_object(params, current_user) do |obj|
      folder = obj.folders.build
      # Set the current user as the creator of the folder, technically, it's posible to override this by using the fld_created_by model field (which is fine)
      folder.created_by = current_user
      save_folder current_user, folder, params[:folder]
    end
  end

  def update
    edit_object(params, current_user) do |obj|
      folder = obj.folders.find {|f| f.id == params[:id].to_i }
      if folder && folder.can_edit?(current_user)
        save_folder current_user, folder, params[:folder]
      else
        render_forbidden
      end
    end
  end

  def show
    find_object(params, current_user) do |obj|
      folder = obj.folders.find {|f| f.id == params[:id].to_i }
      if folder && folder.can_view?(current_user)
        render json: {"folder" => folder_view(current_user, folder)}
      else
        render_forbidden
      end
    end
  end

  def destroy
    edit_object(params, current_user) do |obj|
      folder = obj.folders.find {|f| f.id == params[:id].to_i }

      if folder && folder.can_edit?(current_user)
        folder.archived = true
        folder.save!
        obj.create_async_snapshot(current_user) if obj.respond_to?(:create_async_snapshot)
        render_ok
      else
        render_forbidden
      end
    end
  end


  private

    def folder_view user, folder
      comment_permissions = {}
      folder.comments.each do |c|
        comment_permissions[c.id] = Comment.comment_json_permissions(c, user)
      end

      fields = all_requested_model_field_uids(CoreModule::FOLDER, associations: {"attachments" => CoreModule::ATTACHMENT, "comments" => CoreModule::COMMENT, "groups" => CoreModule::GROUP})
      hash = to_entity_hash(folder, fields, user: user)
      # UI needs child keys even if it's blank, so add it in (the jsonizer doesn't build these..not sure I want to add this in there either)
      hash[:attachments] = [] if hash[:attachments].nil?
      hash[:comments] = [] if hash[:comments].nil?
      hash[:groups] = [] if hash[:groups].nil?

      hash[:comments].each do |comment|
        comment[:permissions] = comment_permissions[comment['id']]
        comment[:permissions] = {} if comment[:permissions].nil?
      end

      hash[:permissions] = {can_attach: folder.can_attach?(user), can_comment: folder.can_comment?(user), can_edit: folder.can_edit?(user)}
      
      hash
    end

    def find_object params, user
      obj = polymorphic_find(params[:base_object_type], params[:base_object_id])
      if obj && obj.can_view?(user)
        yield obj
      else
        render_forbidden
        nil
      end
    end

    def edit_object params, user
      obj = polymorphic_find(params[:base_object_type], params[:base_object_id])
      if obj && obj.respond_to?(:can_attach?) && obj.can_attach?(user)
        yield obj
      else
        render_forbidden
        nil
      end
    end

    def save_folder user, folder, params
      # We ONLY save off folder level data, all other actions on a folder (adding attachments, comments, etc)
      # have their own API calls.
      all_requested_model_fields(CoreModule::FOLDER).each {|mf| mf.process_import(folder, params[mf.uid], user) unless params[mf.uid].nil? }
      folder.save
      if folder.errors.any?
        render_error folder.errors
      else
        folder.base_object.create_async_snapshot(user) if folder.base_object.respond_to?(:create_async_snapshot)
        render json: {"folder" => folder_view(user, folder)}
      end
    end

end; end; end;