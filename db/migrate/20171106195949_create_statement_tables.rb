class CreateStatementTables < ActiveRecord::Migration
  def up

    create_table(:monthly_statements) do |t|
      t.string :statement_number
      t.string :status
      t.date :received_date
      t.date :final_received_date
      t.date :due_date
      t.date :paid_date
      t.string :port_code
      t.string :pay_type
      t.string :customer_number
      t.integer :importer_id
      t.decimal :total_amount, precision: 11, scale: 2
      t.decimal :preliminary_total_amount, precision: 11, scale: 2
      t.decimal :duty_amount, precision: 11, scale: 2
      t.decimal :preliminary_duty_amount, precision: 11, scale: 2
      t.decimal :tax_amount, precision: 11, scale: 2
      t.decimal :preliminary_tax_amount, precision: 11, scale: 2
      t.decimal :cvd_amount, precision: 11, scale: 2
      t.decimal :preliminary_cvd_amount, precision: 11, scale: 2
      t.decimal :add_amount, precision: 11, scale: 2
      t.decimal :preliminary_add_amount, precision: 11, scale: 2
      t.decimal :interest_amount, precision: 11, scale: 2
      t.decimal :preliminary_interest_amount, precision: 11, scale: 2
      t.decimal :fee_amount, precision: 11, scale: 2
      t.decimal :preliminary_fee_amount, precision: 11, scale: 2
      t.string :last_file_bucket
      t.string :last_file_path
      t.datetime :last_exported_from_source
      
      t.timestamps null: false
    end

    add_index :monthly_statements, :statement_number, unique: true
    add_index :monthly_statements, :importer_id

    create_table(:daily_statements) do |t|
      t.string :statement_number
      t.string :monthly_statement_number
      t.integer :monthly_statement_id
      t.string :status
      t.date :received_date
      t.date :final_received_date
      t.date :due_date
      t.date :paid_date
      t.date :payment_accepted_date
      t.string :port_code
      t.string :pay_type
      t.string :customer_number
      t.integer :importer_id
      t.decimal :total_amount, precision: 11, scale: 2
      t.decimal :preliminary_total_amount, precision: 11, scale: 2
      t.decimal :duty_amount, precision: 11, scale: 2
      t.decimal :preliminary_duty_amount, precision: 11, scale: 2
      t.decimal :tax_amount, precision: 11, scale: 2
      t.decimal :preliminary_tax_amount, precision: 11, scale: 2
      t.decimal :cvd_amount, precision: 11, scale: 2
      t.decimal :preliminary_cvd_amount, precision: 11, scale: 2
      t.decimal :add_amount, precision: 11, scale: 2
      t.decimal :preliminary_add_amount, precision: 11, scale: 2
      t.decimal :interest_amount, precision: 11, scale: 2
      t.decimal :preliminary_interest_amount, precision: 11, scale: 2
      t.decimal :fee_amount, precision: 11, scale: 2
      t.decimal :preliminary_fee_amount, precision: 11, scale: 2
      t.string :last_file_bucket
      t.string :last_file_path
      t.datetime :last_exported_from_source
      
      t.timestamps null: false
    end

    add_index :daily_statements, :statement_number, unique: true
    add_index :daily_statements, :importer_id
    add_index :daily_statements, :monthly_statement_id
    add_index :daily_statements, :monthly_statement_number

    create_table(:daily_statement_entries) do |t|
      t.integer :daily_statement_id
      t.string :broker_reference
      t.integer :entry_id
      t.string :port_code
      t.decimal :duty_amount, precision: 11, scale: 2
      t.decimal :preliminary_duty_amount, precision: 11, scale: 2
      t.decimal :tax_amount, precision: 11, scale: 2
      t.decimal :preliminary_tax_amount, precision: 11, scale: 2
      t.decimal :cvd_amount, precision: 11, scale: 2
      t.decimal :preliminary_cvd_amount, precision: 11, scale: 2
      t.decimal :add_amount, precision: 11, scale: 2
      t.decimal :preliminary_add_amount, precision: 11, scale: 2
      t.decimal :fee_amount, precision: 11, scale: 2
      t.decimal :preliminary_fee_amount, precision: 11, scale: 2
      t.decimal :interest_amount, precision: 11, scale: 2
      t.decimal :preliminary_interest_amount, precision: 11, scale: 2
      t.decimal :total_amount, precision: 11, scale: 2
      t.decimal :preliminary_total_amount, precision: 11, scale: 2
      t.decimal :billed_amount, precision: 11, scale: 2

      t.timestamps null: false
    end

    add_index :daily_statement_entries, :daily_statement_id
    add_index :daily_statement_entries, :entry_id
    add_index :daily_statement_entries, :broker_reference

    create_table(:daily_statement_entry_fees) do |t|
      t.integer :daily_statement_entry_id
      t.string :code
      t.string :description
      t.decimal :amount,  precision: 11, scale: 2
      t.decimal :preliminary_amount, precision: 11, scale: 2
    end

    add_index :daily_statement_entry_fees, :daily_statement_entry_id
  end

  def down
    drop_table :daily_statement_entry_fees
    drop_table :daily_statement_entries
    drop_table :daily_statements
    drop_table :monthly_statements
  end
end
