class NonInvoicedEvents < ActiveRecord::Migration
  def self.up
    create_table :non_invoiced_events do |t|
      t.integer :billable_event_id, null: false
      t.string :invoice_generator_name

      t.timestamps
    end

    add_index :non_invoiced_events, :billable_event_id
  end

  def self.down
    drop_table :non_invoiced_events
  end
end
