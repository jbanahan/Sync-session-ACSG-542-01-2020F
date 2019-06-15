class CreateAwsSnapshots < ActiveRecord::Migration
  def up
    create_table :aws_snapshots do |t|
      t.string :snapshot_id
      t.string :description
      t.string :instance_id
      t.string :volume_id
      t.text :tags_json
      t.datetime :start_time
      t.datetime :end_time
      t.boolean :errored
      t.datetime :purged_at

      t.references :aws_backup_session, null: false

      t.timestamps null: false
    end

    add_index :aws_snapshots, :instance_id
    add_index :aws_snapshots, :snapshot_id
    add_index :aws_snapshots, :aws_backup_session_id
  end

  def down
    drop_table :aws_snapshots
  end
end
