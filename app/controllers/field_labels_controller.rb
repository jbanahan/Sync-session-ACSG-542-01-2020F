class FieldLabelsController < ApplicationController
  def index
    if params[:module_type]
      cm = CoreModule.find_by_class_name params[:module_type]
      if cm.nil?
        add_flash :errors, "Invalid module specified, please try again."
      else
        @selected_module = cm.class_name
        @model_fields = ModelField.find_by_module_type cm.class_name.to_sym
      end
    end
  end

  def save
    to_save = params[:field_label]
    to_save.each do |k,v|
      uid = v[:uid]
      current = FieldLabel.label_text uid
      new_val = v[:label]
      if current!=new_val
        FieldLabel.set_label uid, new_val
      end
    end
    add_flash :notices, "Fields updated."
    redirect_to request.referrer
  end
end
