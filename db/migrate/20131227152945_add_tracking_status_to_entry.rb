class AddTrackingStatusToEntry < ActiveRecord::Migration
  def up
    add_column :entries, :tracking_status, :integer
    add_index :entries, :tracking_status
    execute "UPDATE entries SET tracking_status = 1 WHERE source_system = 'Fenix'"
    execute "UPDATE entries SET tracking_status = 0 WHERE source_system = 'Alliance' AND entry_filed_date is null"
    execute "UPDATE entries SET tracking_status = 1 WHERE source_system = 'Alliance' AND entry_filed_date is not null"
  end

  def down
    remove_index :entries, :tracking_status
    remove_column :entries, :tracking_status
  end
end
