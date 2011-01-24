class AddStatusRuleIdToProduct < ActiveRecord::Migration
  def self.up
    add_column :products, :status_rule_id, :integer
  end

  def self.down
    remove_column :products, :status_rule_id
  end
end
