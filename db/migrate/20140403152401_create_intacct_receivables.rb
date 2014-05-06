class CreateIntacctReceivables < ActiveRecord::Migration
  def change
    create_table :intacct_alliance_exports do |t|
      t.string :file_number
      t.string :suffix
      t.datetime :data_requested_date
      t.datetime :data_received_date
      t.timestamps
    end
    add_index :intacct_alliance_exports, [:file_number, :suffix]

    create_table :intacct_receivables do |t|
      t.references :intacct_alliance_export
      t.string :receivable_type
      t.string :company
      t.string :invoice_number
      t.date :invoice_date
      t.string :customer_number
      t.string :currency
      t.datetime :intacct_upload_date
      t.string :intacct_key
      t.text :intacct_errors
      t.timestamps
    end
    add_index :intacct_receivables, :intacct_alliance_export_id
    add_index :intacct_receivables, [:company, :customer_number, :invoice_number], name: 'intacct_recveivables_by_company_customer_number_invoice_number'

    create_table :intacct_receivable_lines do |t|
      t.references :intacct_receivable
      t.decimal :amount, precision: 10, scale: 2
      t.string :charge_code
      t.string :charge_description
      t.string :location
      t.string :line_of_business
      t.string :freight_file
      t.string :broker_file
      t.string :vendor_number
      t.string :vendor_reference
      t.timestamps
    end
    add_index :intacct_receivable_lines, :intacct_receivable_id

    create_table :intacct_payables do |t|
      t.references :intacct_alliance_export
      t.string :company
      t.string :bill_number
      t.date :bill_date
      t.string :vendor_number
      t.string :vendor_reference
      t.string :currency
      t.datetime :intacct_upload_date
      t.string :intacct_key
      t.text :intacct_errors
      t.timestamps
    end
    add_index :intacct_payables, :intacct_alliance_export_id
    add_index :intacct_payables, [:company, :vendor_number, :bill_number], name: 'intacct_payables_by_company_vendor_number_bill_number'

    create_table :intacct_payable_lines do |t|
      t.references :intacct_payable
      t.string :gl_account
      t.decimal :amount, precision: 10, scale: 2
      t.string :customer_number
      t.string :charge_code
      t.string :charge_description
      t.string :location
      t.string :line_of_business
      t.string :freight_file
      t.string :broker_file
      t.string :check_number
      t.string :bank_number
      t.date :check_date
    end
    add_index :intacct_payable_lines, :intacct_payable_id
  end



end
