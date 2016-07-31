class CreateBillableEvents < ActiveRecord::Migration
  def self.up
    create_table :billable_events do |t|
      t.references :billable_eventable, :polymorphic => true, null: false
      t.integer :entity_snapshot_id, null: false
      t.string :event_type

      t.timestamps
    end

    add_index :billable_events, [:billable_eventable_type, :billable_eventable_id], :name => "index_billable_events_on_billable_eventable"
    add_index :billable_events, :entity_snapshot_id
  end

  def self.down
    drop_table :billable_events
  end
end
