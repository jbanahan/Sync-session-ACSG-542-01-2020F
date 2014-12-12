class ModelFieldsController < ApplicationController
  def find_by_module_type
    mfs = custom_hash_for_json ModelField.sort_by_label(CoreModule.find_by_class_name(params[:module_type]).model_fields_including_children(current_user).values)
    render :json => mfs.to_json 
  end

  def glossary
    @cm = CoreModule.find_by_class_name(params[:core_module],true)
    return error_redirect "Module #{params[:core_module]} was not found." if @cm.nil?
    @label = @cm.label
    @fields = @cm.model_fields_including_children(current_user).values
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
