class CreateBrokerInvoiceLines < ActiveRecord::Migration
  def self.up
    create_table :broker_invoice_lines do |t|
      t.integer :broker_invoice_id
      t.string :charge_code
      t.string :charge_description
      t.decimal :charge_amount
      t.string :vendor_name
      t.string :vendor_reference
      t.string :charge_type
      t.timestamps
    end

    add_index :broker_invoice_lines, :broker_invoice_id
    add_index :broker_invoice_lines, :charge_code
  end

  def self.down
    drop_table :broker_invoice_lines
  end
end
