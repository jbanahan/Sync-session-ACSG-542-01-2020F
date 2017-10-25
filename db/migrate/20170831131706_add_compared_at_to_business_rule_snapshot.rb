class AddComparedAtToBusinessRuleSnapshot < ActiveRecord::Migration
  def self.up
    add_column :business_rule_snapshots, :compared_at, :datetime
    execute "UPDATE business_rule_snapshots SET compared_at = now();"
  end

  def self.down
    remove_column :business_rule_snapshots, :compared_at
  end
end
