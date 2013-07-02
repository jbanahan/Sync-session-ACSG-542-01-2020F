class SetFenixEntryBrokerInvoiceTotals < ActiveRecord::Migration
  def up
    sql = <<SQL
UPDATE entries 
SET broker_invoice_total = (SELECT SUM(broker_invoices.invoice_total) 
                            FROM broker_invoices 
                            WHERE entries.id = broker_invoices.entry_id) 
WHERE entries.source_system = 'Fenix' 
SQL
    execute sql
  end

  def down
  end
end
