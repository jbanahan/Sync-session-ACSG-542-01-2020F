class AddDeletedToBusinessRuleSnapshots < ActiveRecord::Migration
  def change
    add_column :business_rule_snapshots, :deleted, :boolean
  end
end
