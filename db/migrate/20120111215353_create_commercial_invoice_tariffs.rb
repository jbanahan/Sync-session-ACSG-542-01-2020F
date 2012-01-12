class CreateCommercialInvoiceTariffs < ActiveRecord::Migration
  def self.up
    create_table :commercial_invoice_tariffs do |t|
      t.integer :commercial_invoice_line_id
      t.string :hts_code
      t.decimal :duty_amount, :precision=>12, :scale=>2
      t.decimal :entered_value, :precision=>13, :scale=>2
      t.string  :spi_primary
      t.string :spi_secondary
      t.decimal :classifcation_qty_1, :precision=>12, :scale=>2
      t.string :classifcation_uom_1 
      t.decimal :classifcation_qty_2, :precision=>12, :scale=>2
      t.string :classifcation_uom_2 
      t.decimal :classifcation_qty_3, :precision=>12, :scale=>2
      t.string :classifcation_uom_3 
      t.integer :gross_weight, :integer
      t.timestamps
    end

    add_index :commercial_invoice_tariffs, :commercial_invoice_line_id
    add_index :commercial_invoice_tariffs, :hts_code
  end

  def self.down
    drop_table :commercial_invoice_tariffs
  end
end
