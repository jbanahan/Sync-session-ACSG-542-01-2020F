class AddDisabledToBusinessValidationRules < ActiveRecord::Migration
  def change
    add_column :business_validation_rules, :disabled, :boolean
  end
end
