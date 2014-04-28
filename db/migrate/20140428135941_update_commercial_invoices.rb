class UpdateCommercialInvoices < ActiveRecord::Migration
  def up
    say_with_time "Updating Fenix commercial invoices..." do
      update <<-SQL
        UPDATE commercial_invoices
        INNER JOIN entries ON entries.id = commercial_invoices.entry_id
        SET commercial_invoices.invoice_value_foreign = commercial_invoices.invoice_value
        WHERE entries.source_system = "Fenix"
      SQL

      update <<-SQL
        UPDATE commercial_invoices
        INNER JOIN entries ON entries.id = commercial_invoices.entry_id
        SET commercial_invoices.invoice_value = commercial_invoices.invoice_value_foreign * commercial_invoices.exchange_rate
        WHERE entries.source_system = "Fenix"
      SQL
    end

    say_with_time "Updating Alliance commercial invoices..." do
      update <<-SQL
        UPDATE commercial_invoices
        INNER JOIN entries on entries.id = commercial_invoices.entry_id
        SET commercial_invoices.invoice_value = commercial_invoices.invoice_value_foreign * commercial_invoices.exchange_rate
        WHERE entries.source_system = "Alliance"
      SQL
    end
  end

  def down
  end

end
