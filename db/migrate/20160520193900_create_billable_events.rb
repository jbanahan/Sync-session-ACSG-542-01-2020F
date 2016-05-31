class CreateBillableEvents < ActiveRecord::Migration
  def self.up
    create_table :billable_events do |t|
      t.references :eventable, :polymorphic => true, null: false
      t.integer :entity_snapshot_id, null: false
      t.string :event_type

      t.timestamps
    end

    add_index :billable_events, [:eventable_type, :eventable_id]
    add_index :billable_events, :entity_snapshot_id
  end

  def self.down
    drop_table :billable_events
  end
end
