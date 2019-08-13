class AddGtnTimeModifierToMilestoneNotificationConfigs < ActiveRecord::Migration
  def change
    add_column :milestone_notification_configs, :gtn_time_modifier, :boolean
  end
end
