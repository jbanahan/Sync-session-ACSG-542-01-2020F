class AddParentSystemCodeToMilestoneNotificationConfigs < ActiveRecord::Migration
  def up
    add_column :milestone_notification_configs, :parent_system_code, :string
    add_index(:milestone_notification_configs, [:module_type, :parent_system_code, :testing], name: "idx_milestone_configs_on_type_parent_sys_code_testing")
  end

  def down
    remove_index(:milestone_notification_configs, name: "idx_milestone_configs_on_type_parent_sys_code_testing") if index_exists?(:milestone_notification_configs, [:module_type, :parent_system_code, :testing], name: "idx_milestone_configs_on_type_parent_sys_code_testing")
    remove_column :milestone_notification_configs, :parent_system_code
  end
end
