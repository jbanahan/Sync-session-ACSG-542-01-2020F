class AddIndexsToFieldValidatorRules < ActiveRecord::Migration
  def change
    add_index(:field_validator_rules, :model_field_uid, unique: true)
    add_index(:field_validator_rules, :custom_definition_id, unique: true)
  end
end
