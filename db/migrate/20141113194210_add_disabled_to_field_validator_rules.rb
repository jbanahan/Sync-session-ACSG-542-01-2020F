class AddDisabledToFieldValidatorRules < ActiveRecord::Migration
  def change
    add_column :field_validator_rules, :disabled, :boolean
  end
end
