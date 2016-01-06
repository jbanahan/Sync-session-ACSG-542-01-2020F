class AddGroupIdToBusinessValidationRules < ActiveRecord::Migration
  def self.up
    add_column :business_validation_rules, :group_id, :integer
  end

  def self.down
    remove_column :business_validation_rules, :group_id
  end
end
