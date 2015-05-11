class CreateMilestoneNotificationConfigs < ActiveRecord::Migration
  def change
    create_table :milestone_notification_configs do |t|
      t.string :customer_number
      t.text :setup
    end

    add_index :milestone_notification_configs, :customer_number

    add_column :search_criterions, :milestone_notification_config_id, :integer
    add_index :search_criterions, :milestone_notification_config_id
  end
end
