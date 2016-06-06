class CreateVfiInvoices < ActiveRecord::Migration
  def self.up
    create_table :vfi_invoices do |t|
      t.integer :customer_id, null: false
      t.date :invoice_date
      t.string :invoice_number
      t.string :currency
      
      t.timestamps
    end
    
    add_index :vfi_invoices, [:customer_id, :invoice_number], unique: true
  end

  def self.down
    drop_table :vfi_invoices
  end
end
