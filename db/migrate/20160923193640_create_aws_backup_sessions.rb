class CreateAwsBackupSessions < ActiveRecord::Migration
  def up
    create_table :aws_backup_sessions do |t|
      t.string :name
      t.datetime :start_time
      t.datetime :end_time
      t.text :log

      t.timestamps null: false
    end
  end

  def down
    drop_table :aws_backup_sessions
  end
end
