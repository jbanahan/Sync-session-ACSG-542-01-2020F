class CustomValue < ActiveRecord::Base
  belongs_to :custom_definition
  belongs_to :customizable, :polymorphic => true
  validates  :custom_definition, :presence => true
  validates  :customizable_id, :presence => true
  validates  :customizable_type, :presence => true
  validate   :validate_unique_record_per_object_and_definition
  
  def value
    d = self.custom_definition
    raise "Cannot get custom value without a custom definition" if d.nil?
    self.send "#{d.data_type}_value"
  end

  def value=(val)
    d = self.custom_definition
    raise "Cannot set custom value without a custom definition" if d.nil?
    self.send "#{d.data_type}_value=", val
  end
  
  private
  def validate_unique_record_per_object_and_definition
    found = CustomValue.where(:customizable_id => self.customizable_id,
      :customizable_type => self.customizable_type,
      :custom_definition_id => self.custom_definition_id).first
    if !found.nil? && self.id != found.id
      self.errors[:base] << "A field value is already associated with #{@customizable_type}: #{@customizable_id} for field with definition id: #{@custom_definition_id}"
    end 
  end
end
