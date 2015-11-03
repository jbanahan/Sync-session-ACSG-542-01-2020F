class AddS3FieldsToEntitySnapshot < ActiveRecord::Migration
  def up
    change_table :entity_snapshots, bulk: true do |t|
      t.string :bucket
      t.string :doc_path
      t.string :version
      t.datetime :compared_at
    end
    add_index :entity_snapshots, [:bucket, :doc_path, :compared_at], name: 'Uncompared Items'
  end

  def down
    change_table :entity_snapshots, bulk: true do |t|
      # By virtue of removing every column referenced by the index above, the index itself is dropped
      t.remove :bucket, :doc_path, :version, :compared_at
    end
  end
end
