class AddAllowAllViewToFieldValidatorRules < ActiveRecord::Migration
  def change
    add_column :field_validator_rules, :allow_everyone_to_view, :boolean
  end
end
