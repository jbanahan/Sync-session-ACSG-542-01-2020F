class CreateErrorLogEntries < ActiveRecord::Migration
  def self.up
    create_table :error_log_entries do |t|
      t.string :exception_class
      t.text :error_message
      t.text :additional_messages_json
      t.text :backtrace_json

      t.timestamps
    end
  end

  def self.down
    drop_table :error_log_entries
  end
end
