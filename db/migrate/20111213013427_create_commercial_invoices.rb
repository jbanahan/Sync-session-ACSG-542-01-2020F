class CreateCommercialInvoices < ActiveRecord::Migration
  def self.up
    create_table :commercial_invoices do |t|
      t.string :invoice_number
      t.string :vendor_name
      t.integer :entry_id

      t.timestamps
    end
  end

  def self.down
    drop_table :commercial_invoices
  end
end
