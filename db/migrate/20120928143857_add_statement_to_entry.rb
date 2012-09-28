class AddStatementToEntry < ActiveRecord::Migration
  def self.up
    add_column :entries, :daily_statement_number, :string
    add_column :entries, :daily_statement_due_date, :date
    add_column :entries, :daily_statement_approved_date, :date
    add_column :entries, :monthly_statement_number, :string
    add_column :entries, :monthly_statement_due_date, :date
    add_column :entries, :monthly_statement_received_date, :date
    add_column :entries, :monthly_statement_paid_date, :date
    add_column :entries, :pay_type, :integer
  end

  def self.down
    remove_column :entries, :pay_type
    remove_column :entries, :monthly_statement_paid_date
    remove_column :entries, :monthly_statement_received_date
    remove_column :entries, :monthly_statement_due_date
    remove_column :entries, :monthly_statement_number
    remove_column :entries, :daily_statement_approved_date
    remove_column :entries, :daily_statement_due_date
    remove_column :entries, :daily_statement_number
  end
end
