class AddIndexsToFieldValidatorRules < ActiveRecord::Migration
  def change
    add_index(:field_validator_rules, :model_field_uid, unique: true)
    add_index(:field_validator_rules, [:custom_definition_id, :model_field_uid], unique: true, name: "index_field_validator_rules_on_cust_def_id_and_model_field_uid")
  end
end
