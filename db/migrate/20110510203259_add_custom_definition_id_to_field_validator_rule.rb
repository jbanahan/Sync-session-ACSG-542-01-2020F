class AddCustomDefinitionIdToFieldValidatorRule < ActiveRecord::Migration
  def self.up
    add_column :field_validator_rules, :custom_definition_id, :integer
  end

  def self.down
    remove_column :field_validator_rules, :custom_definition_id
  end
end
