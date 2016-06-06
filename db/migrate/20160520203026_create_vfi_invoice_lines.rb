class CreateVfiInvoiceLines < ActiveRecord::Migration
  def self.up
    create_table :vfi_invoice_lines do |t|
      t.integer :vfi_invoice_id, null: false
      t.integer :line_number
      t.string :charge_description
      t.decimal :charge_amount, :precision => 11, :scale => 2
      t.string :charge_code
      t.decimal :quantity, :precision => 11, :scale => 2
      t.string :unit
      t.decimal :unit_price, :precision => 11, :scale => 2

      t.timestamps
    end

    add_index :vfi_invoice_lines, :vfi_invoice_id
  end

  def self.down
    drop_table :vfi_invoice_lines
  end
end
