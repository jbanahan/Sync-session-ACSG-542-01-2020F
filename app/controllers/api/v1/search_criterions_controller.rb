module Api; module V1; class SearchCriterionsController < ApiController
  include PolymorphicFinders

  def create
    validate_access(params[:search_criterion], current_user) do |linked_object|
      criterion = linked_object.search_criterions.create valid_params(params)
      if criterion.errors.any?
        render_error criterion.errors.full_messages
      else
        render json: singular_json(criterion, current_user)
      end
    end
  end


  def update
    validate_access(params[:search_criterion], current_user) do |linked_object|
     criterion = linked_object.search_criterions.find {|c| c.id == params[:id].to_i }
      raise ActiveRecord::RecordNotFound unless criterion

      if criterion.update_attributes(valid_params(params))
        render json: singular_json(criterion, current_user)
      else
        render_error criterion.errors.full_messages
      end
    end
  end

  def destroy
    validate_access(params[:search_criterion], current_user) do |linked_object|
      criterion = linked_object.search_criterions.find {|c| c.id == params[:id].to_i }
      raise ActiveRecord::RecordNotFound unless criterion

      if criterion && criterion.destroy
        render json: {"OK"=>"OK"}
      else
        render_error criterion.errors.full_messages
      end
    end
  end

  def index 
    validate_access(params[:search_criterion], current_user) do |linked_object|
      render json: plural_json(linked_object.search_criterions, current_user)
    end
  end

  private 

    def validate_access crit_params, user
      if crit_params
        obj = polymorphic_find(crit_params[:linked_object_type], crit_params[:linked_object_id])
        if !obj.respond_to?(:can_view?) || obj.can_view?(user)
          yield obj
        else 
          raise ActiveRecord::RecordNotFound
        end
      end
    end

    def to_json criterion, user
      mf = criterion.model_field
      {id: criterion.id, operator: criterion.operator, value: criterion.value, model_field_uid: criterion.model_field_uid, include_empty: criterion.include_empty?, label: (mf.can_view?(current_user) ? mf.label : ModelField.disabled_label), datatype: mf.data_type}
    end

    def singular_json criterion, user
      {search_criterion: to_json(criterion, user)}
    end

    def plural_json criterions, user
      {search_criterions: criterions.map {|c| to_json c, user}}
    end

    def valid_params params
      params[:search_criterion].slice :id, :operator, :value, :model_field_uid, :include_empty
    end

end; end; end;