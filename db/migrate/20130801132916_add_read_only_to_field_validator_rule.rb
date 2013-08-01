class AddReadOnlyToFieldValidatorRule < ActiveRecord::Migration
  def change
    add_column :field_validator_rules, :read_only, :boolean
  end
end
