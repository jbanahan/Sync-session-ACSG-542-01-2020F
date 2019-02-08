class AddInactiveToOneTimeAlerts < ActiveRecord::Migration
  def change
    add_column :one_time_alerts, :inactive, :boolean, default: false
  end
end
