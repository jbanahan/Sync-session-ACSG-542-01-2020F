class AddMassUpdateAndCanMassEditGroupToFieldValidatorRules < ActiveRecord::Migration
  def change
    add_column :field_validator_rules, :mass_edit, :boolean
    add_column :field_validator_rules, :can_mass_edit_groups, :text
  end
end
