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
      save_folder current_user, folder, params
    end
  end

  def update
    edit_object(params, current_user) do |obj|
      folder = obj.folders.find {|f| f.id == params[:id].to_i }
      if folder && folder.can_edit?(current_user)
        save_folder current_user, folder, params
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
        folder.destroy
        obj.create_async_snapshot current_user
        render_ok
      else
        render_forbidden
      end
    end
  end


  private

    def folder_view user, folder
      fields = all_requested_model_field_uids(CoreModule::FOLDER, associations: {"attachments" => CoreModule::ATTACHMENT, "comments" => CoreModule::COMMENT, "groups" => CoreModule::GROUP})
      to_entity_hash(folder, fields, user: user)
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
      if obj && obj.can_edit?(user)
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
        folder.base_object.create_async_snapshot user
        render json: {"folder" => folder_view(user, folder)}
      end
    end

end; end; end;