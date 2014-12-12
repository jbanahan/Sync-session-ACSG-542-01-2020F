class AddEditGroupsViewGroupsToFieldValidatorRules < ActiveRecord::Migration
  def change
    add_column :field_validator_rules, :can_edit_groups, :text
    add_column :field_validator_rules, :can_view_groups, :text
  end
end
