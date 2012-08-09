class AddVfdAndGstTotalsToEntryHeader < ActiveRecord::Migration
  def self.up
    add_column :entries, :total_gst, :decimal, :precision=>11, :scale=>2
    add_column :entries, :total_duty_gst, :decimal, :precision=>11, :scale=>2
    execute "UPDATE entries ent SET ent.total_gst = (select sum(t.gst_amount) FROM commercial_invoices ci INNER JOIN commercial_invoice_lines ln on ln.commercial_invoice_id = ci.id INNER JOIN commercial_invoice_tariffs t on ln.id = t.commercial_invoice_line_id WHERE ci.entry_id = ent.id) WHERE ent.source_system = \"Fenix\""
    execute "UPDATE entries ent SET ent.total_duty_gst = (ent.total_gst + ent.total_duty) WHERE ent.source_system = \"Fenix\""
  end

  def self.down
    remove_column :entries, :total_duty_gst
    remove_column :entries, :total_gst
  end
end
