class ImportConfigMapping < ActiveRecord::Base
  include HoldsCustomDefinition
  belongs_to :import_config
  
  def find_model_field
    ModelField.find_by_uid self[:model_field_uid]
  end
  
  
  
end
