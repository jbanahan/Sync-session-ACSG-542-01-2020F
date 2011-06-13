class CreateEntitySnapshots < ActiveRecord::Migration
  def self.up
    create_table :entity_snapshots do |t|
      t.string :recordable_type
      t.integer :recordable_id
      t.text :snapshot
      t.integer :user_id

      t.timestamps
    end
    add_index :entity_snapshots, [:recordable_id,:recordable_type]
    add_index :entity_snapshots, :user_id
  end

  def self.down
    drop_table :entity_snapshots
  end
end
