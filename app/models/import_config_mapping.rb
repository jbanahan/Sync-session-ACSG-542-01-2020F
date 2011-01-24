class ImportConfigMapping < ActiveRecord::Base
  belongs_to :import_config
  
  def model_field_uid=(model_field_uid)
    self[:model_field_uid] = model_field_uid
    mf = find_model_field
    self.custom_definition_id = mf.custom_id
  end
  
  def find_model_field
    ModelField.find_by_uid self[:model_field_uid]
  end
  
  
end
