class CreateRequestLog < ActiveRecord::Migration
  def up
    create_table(:request_logs) do |t|
      t.integer :user_id
      t.string :http_method
      t.string :url
      t.integer :run_as_session_id

      t.timestamps
    end

    add_index :request_logs, [:user_id]
    add_index :request_logs, [:run_as_session_id]
  end

  def down
    drop_table(:request_logs)
  end
end
