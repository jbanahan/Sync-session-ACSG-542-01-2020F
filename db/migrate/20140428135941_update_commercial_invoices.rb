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
        WHERE (entries.source_system = "Fenix" OR entries.source_system = "Alliance") AND commercial_invoices.exchange_rate <> 1
      SQL
    end
  end

  def down
  end

end