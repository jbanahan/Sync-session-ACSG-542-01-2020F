class BusinessValidationRule < ActiveRecord::Base
  belongs_to :business_validation_template, inverse_of: :business_validation_rules
  attr_accessible :description, :name, :rule_attributes_json, :type, :fail_state

  has_many :search_criterions, dependent: :destroy
  has_many :business_validation_rule_results, dependent: :destroy, inverse_of: :business_validation_rule

  def rule_attributes
    self.rule_attributes_json.blank? ? nil : JSON.parse(self.rule_attributes_json)
  end
end
