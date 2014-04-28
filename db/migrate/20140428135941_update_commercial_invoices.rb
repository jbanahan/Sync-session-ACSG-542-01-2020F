class UpdateCommercialInvoices < ActiveRecord::Migration
  def up
    say_with_time "Updating Fenix commercial invoices..." do
      update <<-SQL
        UPDATE commercial_invoices
        LEFT JOIN entries ON entries.source_system = "Fenix"
        SET commercial_invoices.invoice_value_foreign = commercial_invoices.invoice_value
      SQL

      update <<-SQL
        UPDATE commercial_invoices
        LEFT JOIN entries ON entries.source_system = "Fenix"
        SET commercial_invoices.invoice_value = commercial_invoices.invoice_value_foreign * commercial_invoices.exchange_rate
      SQL
    end

    say_with_time "Updating Alliance commercial invoices..." do
      update <<-SQL
        UPDATE commercial_invoices
        LEFT JOIN entries on entries.source_system = "Alliance"
        SET commercial_invoices.invoice_value = commercial_invoices.invoice_value_foreign * commercial_invoices.exchange_rate
      SQL
    end
  end

  def down
  end

end
