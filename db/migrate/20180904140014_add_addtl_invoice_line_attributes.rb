class AddAddtlInvoiceLineAttributes < ActiveRecord::Migration
  def up
    change_table(:invoice_lines, bulk: true) do |t|
      t.string :po_line_number
      t.string :master_bill_of_lading
      t.string :carrier_code
      t.integer :cartons
      t.string :container_number
      t.boolean :related_parties
      t.decimal :customs_quantity, :precision => 12, :scale => 2
      t.string :customs_quantity_uom
      t.string :spi
      t.string :spi2
    end
  end

  def down
    change_table(:invoice_lines, bulk: true) do |t|
      t.remove :po_line_number
      t.remove :master_bill_of_lading
      t.remove :carrier_code
      t.remove :cartons
      t.remove :container_number
      t.remove :related_parties
      t.remove :customs_quantity
      t.remove :customs_quantity_uom
      t.remove :spi
      t.remove :spi2
    end
  end
end
