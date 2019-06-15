class AddEntityComparatorLogs < ActiveRecord::Migration
  def up
    create_table :entity_comparator_logs do |t|
      t.integer :recordable_id
      t.string  :recordable_type
      t.string  :old_bucket
      t.string  :old_path
      t.string  :old_version
      t.string  :new_bucket
      t.string  :new_path
      t.string  :new_version

      t.timestamps null: false
    end

    add_index :entity_comparator_logs, [:recordable_id, :recordable_type], name: "index_entity_comparator_logs_rec_id_and_rec_type"
  end

  def down
    drop_table :entity_comparator_logs
  end
end
