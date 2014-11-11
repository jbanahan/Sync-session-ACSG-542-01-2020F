class CreateIntacctCheck < ActiveRecord::Migration
  def change
    create_table :intacct_checks do |t|
      t.string :company
      t.string :file_number
      t.string :suffix
      t.string :bill_number
      t.string :customer_number
      t.string :vendor_number
      t.string :check_number
      t.date :check_date
      t.string :bank_number
      t.string :vendor_reference
      t.decimal :amount, precision: 10, scale: 2
      t.string :freight_file
      t.string :broker_file
      t.string :location
      t.string :line_of_business
      t.string :currency
      t.string :gl_account
      t.string :bank_cash_gl_account
      t.references :intacct_alliance_export

      t.datetime :intacct_upload_date
      t.string :intacct_key
      t.text :intacct_errors
      t.references :intacct_payable
      t.string :intacct_adjustment_key

      t.timestamps
    end

    add_index :intacct_checks, :intacct_alliance_export_id
    add_index :intacct_checks, [:file_number, :suffix, :check_number, :check_date, :bank_number], name: 'index_by_check_unique_identifers'
    add_index :intacct_checks, [:company, :bill_number, :vendor_number], name: "index_by_payable_identifiers"
  end
end
