class CreateInvoiceLines < ActiveRecord::Migration
  def up
    create_table :invoice_lines do |t|
      t.decimal :air_sea_discount, :precision => 12, :scale => 2
      t.integer :country_export_id
      t.integer :country_origin_id
      t.string  :department
      t.decimal :early_pay_discount, :precision => 12, :scale => 2
      t.boolean :first_sale
      t.boolean :fish_wildlife
      t.integer :gross_weight
      t.string  :gross_weight_uom
      t.string  :hts_number
      t.integer :invoice_id
      t.integer :line_number
      t.string  :mid
      t.decimal :middleman_charge, :precision => 12, :scale => 2
      t.decimal :net_weight, :precision => 12, :scale => 2
      t.string  :net_weight_uom
      t.integer :order_id
      t.integer :order_line_id
      t.string  :part_description
      t.string  :part_number
      t.decimal :pieces, :precision => 13, :scale => 4
      t.string  :po_number
      t.integer :product_id
      t.decimal :quantity, :precision => 12, :scale => 3
      t.string  :quantity_uom
      t.decimal :trade_discount, :precision => 12, :scale => 2
      t.decimal :unit_price, :precision => 12, :scale => 3
      t.decimal :value_domestic, :precision => 13, :scale => 2
      t.decimal :value_foreign, :precision => 11, :scale =>2
      t.integer :variant_id
      t.decimal :volume, :precision => 11, :scale => 2
      t.string  :volume_uom

      t.timestamps null: false
    end

    add_index :invoice_lines, :invoice_id
  end

  def down
    drop_table :invoice_lines
  end
end
