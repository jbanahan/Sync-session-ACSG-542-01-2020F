class CreateBulkProcessLogs < ActiveRecord::Migration
  def up
    create_table :bulk_process_logs do |t|
      t.references :user
      t.string :bulk_type
      t.timestamp :started_at
      t.timestamp :finished_at
      t.integer :total_object_count
      t.integer :changed_object_count

      t.timestamps
    end

    add_column :change_records, :bulk_process_log_id, :integer
    add_index :change_records, :bulk_process_log_id

    add_column :entity_snapshots, :change_record_id, :integer
    add_index :entity_snapshots, :change_record_id

    add_column :entity_snapshots, :bulk_process_log_id, :integer
    add_index :entity_snapshots, :bulk_process_log_id
  end

  def down
    remove_column :entity_snapshots, :bulk_process_log_id
    remove_column :entity_snapshots, :change_record_id
    remove_column :change_records, :bulk_process_log_id
    drop_table :bulk_process_logs
  end
end
