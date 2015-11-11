class AddModuleTypeToMilestoneNotificationConfig < ActiveRecord::Migration
  def up
    add_column :milestone_notification_configs, :module_type, :string
    remove_index :milestone_notification_configs, name: "index_milestone_configs_on_cust_no_testing"
    execute "UPDATE milestone_notification_configs SET module_type = 'Entry'"
    add_index :milestone_notification_configs, [:module_type, :customer_number, :testing], name: "index_milestone_configs_on_type_cust_no_testing"
  end

  def down
    remove_index :milestone_notification_configs, name: "index_milestone_configs_on_type_cust_no_testing"
    remove_column :milestone_notification_configs, :module_type
    add_index :milestone_notification_configs, [:customer_number, :testing], name: "index_milestone_configs_on_cust_no_testing"
  end
end
