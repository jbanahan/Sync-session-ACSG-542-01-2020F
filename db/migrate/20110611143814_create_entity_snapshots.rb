class CreateEntitySnapshots < ActiveRecord::Migration
  def self.up
    create_table :entity_snapshots do |t|
      t.string :recordable_type
      t.integer :recordable_id
      t.text :snapshot
      t.integer :user_id

      t.timestamps
    end
  end

  def self.down
    drop_table :entity_snapshots
  end
end
