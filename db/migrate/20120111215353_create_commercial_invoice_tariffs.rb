class CreateCommercialInvoiceTariffs < ActiveRecord::Migration
  def self.up
    create_table :commercial_invoice_tariffs do |t|
      t.integer :commercial_invoice_line_id
      t.string :hts_code
      t.decimal :duty_amount, :precision=>12, :scale=>2
      t.decimal :entered_value, :precision=>13, :scale=>2
      t.string  :spi_primary
      t.string :spi_secondary
      t.decimal :classification_qty_1, :precision=>12, :scale=>2
      t.string :classification_uom_1 
      t.decimal :classification_qty_2, :precision=>12, :scale=>2
      t.string :classification_uom_2 
      t.decimal :classification_qty_3, :precision=>12, :scale=>2
      t.string :classification_uom_3 
      t.integer :gross_weight, :integer
      t.string :tariff_description
      t.timestamps
    end

    add_index :commercial_invoice_tariffs, :commercial_invoice_line_id
    add_index :commercial_invoice_tariffs, :hts_code
  end

  def self.down
    drop_table :commercial_invoice_tariffs
  end
end
