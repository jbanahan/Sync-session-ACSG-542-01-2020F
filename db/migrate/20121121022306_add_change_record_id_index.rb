class AddChangeRecordIdIndex < ActiveRecord::Migration
  def self.up
    add_index :change_record_messages, :change_record_id
  end

  def self.down
    remove_index :change_record_messages, :change_record_id
  end
end
