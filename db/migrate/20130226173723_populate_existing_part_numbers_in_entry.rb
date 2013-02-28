class PopulateExistingPartNumbersInEntry < ActiveRecord::Migration
  def up
    execute <<-SQL
      SET SESSION group_concat_max_len = 50000
    SQL
    execute <<-SQL
      update entries set part_numbers = 
      (select 
      (group_concat(distinct part_number order by part_number ASC SEPARATOR "\n")) as "pn"
      from commercial_invoices cl 
      inner join commercial_invoice_lines cil on cl.id = cil.commercial_invoice_id and length(cil.part_number) > 0
      where cl.entry_id = entries.id)
    SQL
  end

  def down
    execute "update entries set part_numbers = null" 
  end
end
