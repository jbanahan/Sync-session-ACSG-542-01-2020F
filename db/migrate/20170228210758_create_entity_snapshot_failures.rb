class CreateEntitySnapshotFailures < ActiveRecord::Migration
  def up
    create_table :entity_snapshot_failures do |t|
      t.integer :snapshot_id
      t.string :snapshot_type
      t.text :snapshot_json, limit: 4294967295

      t.timestamps
    end
  end

  def down
    drop_table :entity_snapshot_failures
  end
end
