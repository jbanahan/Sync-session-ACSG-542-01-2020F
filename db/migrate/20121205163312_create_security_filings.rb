class CreateSecurityFilings < ActiveRecord::Migration
  def self.up
    create_table :security_filings do |t|
      t.string :transaction_number
      t.string :host_system_file_number
      t.string :host_system
      t.integer :importer_id
      t.string :importer_account_code
      t.string :broker_customer_number
      t.string :importer_tax_id
      t.string :transport_mode_code
      t.string :scac
      t.string :booking_number
      t.string :vessel
      t.string :voyage
      t.string :lading_port_code
      t.string :unlading_port_code
      t.string :entry_port_code
      t.string :status_code
      t.boolean :late_filing
      t.string :master_bill_of_lading
      t.string :house_bills_of_lading
      t.string :container_numbers
      t.string :entry_numbers
      t.string :entry_reference_numbers
      t.datetime :file_logged_date
      t.datetime :first_sent_date
      t.datetime :first_accepted_date
      t.datetime :last_sent_date
      t.datetime :last_accepted_date
      t.date :estimated_vessel_load_date
      t.string :po_numbers

      t.timestamps
    end
    add_index :security_filings,  :importer_id
    add_index :security_filings,  :host_system_file_number
    add_index :security_filings,  :host_system
    add_index :security_filings,  :transaction_number
    add_index :security_filings,  :first_accepted_date
    add_index :security_filings,  :first_sent_date
    add_index :security_filings,  :estimated_vessel_load_date
    add_index :security_filings,  :entry_numbers
    add_index :security_filings,  :entry_reference_numbers
    add_index :security_filings,  :master_bill_of_lading
    add_index :security_filings,  :house_bills_of_lading
    add_index :security_filings,  :po_numbers
    add_index :security_filings,  :container_numbers

    add_column :histories, :security_filing_id, :integer
    add_index :histories, :security_filing_id

    add_column :item_change_subscriptions, :security_filing_id, :integer
    add_index :item_change_subscriptions, :security_filing_id
  end

  def self.down
    remove_index :item_change_subscriptions, :security_filing_id
    remove_column :item_change_subscriptions, :security_filing_id
    remove_index :histories, :security_filing_id
    remove_column :histories, :security_filing_id
    drop_table :security_filings
  end
end
