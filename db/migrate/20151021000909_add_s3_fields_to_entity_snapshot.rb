class AddS3FieldsToEntitySnapshot < ActiveRecord::Migration
  def change
    add_column :entity_snapshots, :bucket, :string
    add_column :entity_snapshots, :doc_path, :string
    add_column :entity_snapshots, :version, :string
    add_column :entity_snapshots, :compared_at, :datetime
    add_index :entity_snapshots, [:bucket, :doc_path, :compared_at], name: 'Uncompared Items'
  end
end
