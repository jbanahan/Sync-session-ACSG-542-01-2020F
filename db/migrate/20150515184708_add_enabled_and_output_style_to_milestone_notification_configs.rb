class AddEnabledAndOutputStyleToMilestoneNotificationConfigs < ActiveRecord::Migration
  def change
    add_column :milestone_notification_configs, :enabled, :boolean
    add_column :milestone_notification_configs, :output_style, :string
  end
end
