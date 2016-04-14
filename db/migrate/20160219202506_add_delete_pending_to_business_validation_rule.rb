class AddDeletePendingToBusinessValidationRule < ActiveRecord::Migration
  def up
    add_column :business_validation_rules, :delete_pending, :boolean
  end

  def down
    remove_column :business_validation_rules, :delete_pending
  end
end
