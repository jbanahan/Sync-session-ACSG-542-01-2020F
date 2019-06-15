class CreateInvoicedEvents < ActiveRecord::Migration
  def self.up
    create_table :invoiced_events do |t|
      t.integer :billable_event_id, null: false
      t.integer :vfi_invoice_line_id
      t.string :invoice_generator_name
      t.string :charge_type

      t.timestamps null: false
    end

    add_index :invoiced_events, :billable_event_id
    add_index :invoiced_events, :vfi_invoice_line_id
  end

  def self.down
    drop_table :invoiced_events
  end
end
