class CreateSyncRecords < ActiveRecord::Migration
  def self.up
    create_table :sync_records do |t|
      t.integer :syncable_id
      t.string :syncable_type
      t.string :trading_partner
      t.datetime :sent_at
      t.datetime :confirmed_at
      t.string :confirmation_file_name
      t.string :failure_message

      t.timestamps
    end
    add_index :sync_records, [:syncable_id,:syncable_type]
    add_index :sync_records, :trading_partner
  end

  def self.down
    drop_table :sync_records
  end
end
