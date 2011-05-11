class CreateChangeRecordMessages < ActiveRecord::Migration
  def self.up
    create_table :change_record_messages do |t|
      t.integer :change_record_id
      t.string :message

      t.timestamps
    end
  end

  def self.down
    drop_table :change_record_messages
  end
end
