class CreateCommercialInvoiceLines < ActiveRecord::Migration
  def self.up
    create_table :commercial_invoice_lines do |t|
      t.string :part_number
      t.string :part_description
      t.integer :line_number
      t.string :po_number
      t.string :hts_number
      t.decimal :units, :precision => 11, :scale => 2
      t.string :unit_of_measure
      t.decimal :duty_rate, :precision => 11, :scale => 2
      t.integer :commercial_invoice_id

      t.timestamps
    end
  end

  def self.down
    drop_table :commercial_invoice_lines
  end
end
