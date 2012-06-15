class SetFenixEnteredValue < ActiveRecord::Migration
  def self.up
    execute "UPDATE entries ent SET ent.entered_value = (select sum(t.entered_value) FROM commercial_invoices ci INNER JOIN commercial_invoice_lines ln on ln.commercial_invoice_id = ci.id INNER JOIN commercial_invoice_tariffs t on ln.id = t.commercial_invoice_line_id WHERE ci.entry_id = ent.id) WHERE ent.source_system = \"Fenix\""
  end

  def self.down
    execute "UPDATE entries ent set ent.entered_value = null where ent.source_system = \"Fenix\""
  end
end
