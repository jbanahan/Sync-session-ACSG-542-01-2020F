class AddTestingToMilestonNotificationConfigs < ActiveRecord::Migration
  def up
    add_column :milestone_notification_configs, :testing, :boolean
    remove_index :milestone_notification_configs, [:customer_number]
    add_index :milestone_notification_configs, [:customer_number, :testing], unique: true, name: "index_milestone_configs_on_cust_no_testing"
  end

  def down
    remove_index :milestone_notification_configs, name: "index_milestone_configs_on_cust_no_testing"
    remove_column :milestone_notification_configs, :testing
    add_index :milestone_notification_configs, [:customer_number]
  end
end
