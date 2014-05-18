class AddIgnoreUpdatesBeforeToSyncRecord < ActiveRecord::Migration
  def change
    add_column :sync_records, :ignore_updates_before, :datetime
  end
end
