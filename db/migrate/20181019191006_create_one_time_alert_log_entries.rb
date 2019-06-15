class CreateOneTimeAlertLogEntries < ActiveRecord::Migration
  def self.up
    create_table :one_time_alert_log_entries do |t|
      t.integer :one_time_alert_id
      t.datetime :logged_at
      t.integer :alertable_id
      t.string :alertable_type
      t.string :reference_fields

      t.timestamps null: false
    end
  end

  def self.down
    drop_table :one_time_alert_log_entries
  end
end
