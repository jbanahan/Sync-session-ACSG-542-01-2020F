class AddIndexToErrorLogEntries < ActiveRecord::Migration
  def up
    add_index :error_log_entries, :created_at
  end

  def down
    remove_index :error_log_entries, :created_at
  end
end
