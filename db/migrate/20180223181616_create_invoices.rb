class CreateInvoices < ActiveRecord::Migration
  def up
    create_table :invoices do |t|
      t.integer  :country_origin_id
      t.string   :currency 
      t.string   :customer_reference_number
      t.text     :description_of_goods
      t.decimal  :exchange_rate, :precision => 8, :scale => 6
      t.integer  :factory_id
      t.decimal  :gross_weight, :precision => 11, :scale => 2
      t.string   :gross_weight_uom
      t.integer  :importer_id
      t.date     :invoice_date
      t.string   :invoice_number
      t.decimal  :invoice_total_domestic, :precision => 13, :scale => 2
      t.decimal  :invoice_total_foreign, :precision => 13, :scale => 2
      t.decimal  :net_invoice_total, :precision => 13, :scale => 2
      t.decimal  :net_weight, :precision => 11, :scale => 2
      t.string   :net_weight_uom
      t.string   :ship_mode
      t.integer  :ship_to_id
      t.string   :terms_of_payment
      t.string   :terms_of_sale
      t.decimal  :total_charges, :precision => 11, :scale => 2
      t.decimal  :total_discounts, :precision => 12, :scale => 2
      t.integer  :vendor_id
      t.decimal  :volume, :precision => 11, :scale => 5
      t.string   :volume_uom

      t.timestamps
    end
  end

  def down
    drop_table :invoices
  end
end
