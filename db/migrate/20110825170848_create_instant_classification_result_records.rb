class CreateInstantClassificationResultRecords < ActiveRecord::Migration
  def self.up
    create_table :instant_classification_result_records do |t|
      t.integer :instant_classification_result_id
      t.integer :entity_snapshot_id
      t.integer :product_id

      t.timestamps
    end
    add_index :instant_classification_result_records, :instant_classification_result_id, :name=>'result_ids'
  end

  def self.down
    drop_table :instant_classification_result_records
  end
end
