class AddFiscalDateAndFiscalYearAndFiscalMonthToBrokerInvoices < ActiveRecord::Migration
  def self.up
    change_table(:broker_invoices, bulk: true) do |t|
      t.column :fiscal_date, :date
      t.column :fiscal_month, :integer
      t.column :fiscal_year, :integer
    end
  end

  def self.down
    change_table(:broker_invoices, bulk: true) do |t|
      t.remove :fiscal_date
      t.remove :fiscal_month
      t.remove :fiscal_year
    end
  end
end
