class AddOneTimeAlertIdToSearchCriterions < ActiveRecord::Migration
  def self.up
    add_column :search_criterions, :one_time_alert_id, :integer
  end

  def self.down
    remove_column :search_criterions, :one_time_alert_id
  end
end
