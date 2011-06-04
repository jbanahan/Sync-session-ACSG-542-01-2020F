class PublicField < ActiveRecord::Base

  after_save :reload_model_fields

private
  def reload_model_fields
    ModelField.reload true #update flag in cache so other threads reload their model fields
  end

end
