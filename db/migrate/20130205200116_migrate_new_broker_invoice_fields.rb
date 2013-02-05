class MigrateNewBrokerInvoiceFields < ActiveRecord::Migration
  def up
    execute "update broker_invoices 
set invoice_number = (select concat(ifnull(ent.broker_reference,\"\"),broker_invoices.suffix) from entries ent where broker_invoices.entry_id = ent.id), 
source_system = (select ent.source_system from entries ent where ent.id = broker_invoices.entry_id), 
broker_reference = (select ent.broker_reference from entries ent where ent.id = broker_invoices.entry_id)"
  end

  def down
    execute "update broker_invoices set invoice_number = null, source_system = null, broker_reference = null"
  end
end
