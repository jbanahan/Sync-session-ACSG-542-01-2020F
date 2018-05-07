require 'open_chain/api/v1/folder_api_json_generator'

module Api; module V1; class FoldersController < Api::V1::ApiCoreModuleControllerBase
  include PolymorphicFinders

  def index
    find_object(params, current_user) do |obj|
      folders = obj.folders.select {|f| f.can_view?(current_user)}
      json = []
      folders.each do |folder|
        json << obj_to_json_hash(folder)
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
        render json: {"folder" => obj_to_json_hash(folder)}
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

  def json_generator
    OpenChain::Api::V1::FolderApiJsonGenerator.new
  end

  private

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
        render json: {"folder" => obj_to_json_hash(folder)}
      end
    end

end; end; end;