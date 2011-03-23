class PublicField < ActiveRecord::Base

  after_save :reload_model_fields

private
  def reload_model_fields
    ModelField.reload
  end

end
