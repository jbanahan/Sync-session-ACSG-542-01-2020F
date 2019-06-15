class CreateRunAsSession < ActiveRecord::Migration
  def up
    create_table(:run_as_sessions) do |t|
      t.integer :user_id
      t.integer :run_as_user_id
      t.datetime :start_time
      t.datetime :end_time

      t.timestamps null: false
    end

    add_index :run_as_sessions, [:user_id]
    add_index :run_as_sessions, [:run_as_user_id]
    add_index :run_as_sessions, [:start_time]
  end

  def down
    drop_table :run_as_sessions
  end
end
