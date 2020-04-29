module HoldsCustomDefinition
  def self.included(base)
    base.instance_eval("belongs_to :custom_definition")
    base.instance_eval("before_save :set_custom_definition_id")
  end

  def model_field_uid=(model_field_uid)
    self[:model_field_uid] = model_field_uid
    if !model_field_uid.blank?
      mf = ModelField.find_by_uid model_field_uid
      self.custom_definition_id = mf.custom_id unless mf.blank?
    end
    self[:model_field_uid]
  end

  def model_field
    find_model_field
  end
  def find_model_field
    ModelField.find_by_uid self[:model_field_uid]
  end

  def custom_field?
    find_model_field.custom?
  end

  private

  def set_custom_definition_id
    if !self.model_field_uid.nil? && self.model_field_uid.to_s.starts_with?("*cf_")
    self.custom_definition_id = self.model_field_uid.to_s[4, self.model_field_uid.to_s.length-1].to_i
    end
  end
end
