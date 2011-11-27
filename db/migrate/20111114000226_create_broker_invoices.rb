class CreateBrokerInvoices < ActiveRecord::Migration
  def self.up
    create_table :broker_invoices do |t|
      t.integer :entry_id
      t.string :suffix
      t.date :invoice_date
      t.string :customer_number
      t.decimal :invoice_total, :precision => 11, :scale => 2
      t.string :bill_to_name
      t.string :bill_to_address_1
      t.string :bill_to_address_2
      t.string :bill_to_city
      t.string :bill_to_state
      t.string :bill_to_zip
      t.integer :bill_to_country_id

      t.timestamps
    end
    add_index :broker_invoices, :entry_id
    add_index :broker_invoices, :invoice_date
    add_index :broker_invoices, :customer_number
  end

  def self.down
    drop_table :broker_invoices
  end
end
