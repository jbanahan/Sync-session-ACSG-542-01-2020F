class ModelFieldsController < ApplicationController
  def find_by_module_type
    model_fields = ModelField.sort_by_label(CoreModule.find_by_class_name(params[:module_type]).model_fields_including_children.values)
    mfs = custom_hash_for_json model_fields.select {|m| m.can_view? current_user}
    render :json => mfs.to_json 
  end

  def glossary
    cm = CoreModule.find_by_class_name(params[:core_module],true)
    @label = cm.label.blank? ? "Unlabled Module" : cm.label
    @fields = cm.nil? ? [] : cm.model_fields_including_children.values
  end
  
  private
  def custom_hash_for_json(mfs)
    r = []
    mfs.each do |m|
      r << {:uid => m.uid, :label => m.label}
    end
    r
  end
end
