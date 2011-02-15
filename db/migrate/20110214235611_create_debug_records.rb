class CreateDebugRecords < ActiveRecord::Migration
  def self.up
    create_table :debug_records do |t|
      t.integer :user_id
      t.string :request_method
      t.text :request_params
      t.string :request_path

      t.timestamps
    end
  end

  def self.down
    drop_table :debug_records
  end
end
