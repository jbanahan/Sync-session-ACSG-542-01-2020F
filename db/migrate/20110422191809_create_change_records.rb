class CreateChangeRecords < ActiveRecord::Migration
  def self.up
    create_table :change_records do |t|
      t.integer :file_import_result_id
      t.integer :recordable_id
      t.string :recordable_type
      t.integer :record_sequence_number

      t.timestamps
    end
  end

  def self.down
    drop_table :change_records
  end
end
