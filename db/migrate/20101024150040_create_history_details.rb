class CreateHistoryDetails < ActiveRecord::Migration
  def self.up
    create_table :history_details do |t|
      t.integer :history_id
      t.string :key
      t.string :value

      t.timestamps
    end
  end

  def self.down
    drop_table :history_details
  end
end
