class DropAndRecreateBadFieldValidatorRuleIndex < ActiveRecord::Migration
  def up
    if index_exists?(:field_validator_rules, :custom_definition_id)
      remove_index(:field_validator_rules, :custom_definition_id)
      unless index_exists?(:field_validator_rules, [:custom_definition_id, :model_field_uid], unique: true, name: "index_field_validator_rules_on_cust_def_id_and_model_field_uid")
        add_index(:field_validator_rules, [:custom_definition_id, :model_field_uid], unique: true, name: "index_field_validator_rules_on_cust_def_id_and_model_field_uid")
      end
      
    end
  end

  def down
  end
end
