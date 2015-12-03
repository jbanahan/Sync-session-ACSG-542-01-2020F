class AddSummaryStatementIdToBrokerInvoice < ActiveRecord::Migration
  def self.up
    add_column :broker_invoices, :summary_statement_id, :integer
    add_index :broker_invoices, :summary_statement_id
  end

  def self.down
    remove_column :broker_invoices, :summary_statement_id
    remove_index :broker_invoices, :summary_statement_id
  end
end
