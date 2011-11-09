class CreateCustomFileRecords < ActiveRecord::Migration
  def self.up
    create_table :custom_file_records do |t|
      t.string :linked_object_type
      t.integer :linked_object_id
      t.integer :custom_file_id

      t.timestamps
    end
  end

  def self.down
    drop_table :custom_file_records
  end
end
