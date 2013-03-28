class PopulateExistingCommercialInvoiceNumbersInEntry < ActiveRecord::Migration
  def up
  	execute <<-SQL
  		SET SESSION group_concat_max_len = 50000
  	SQL
  	execute <<-SQL
  		update entries set commercial_invoice_numbers = 
				(select 
      		(group_concat(distinct invoice_number order by invoice_number ASC SEPARATOR "\n")) as 'inv_number'
      	from commercial_invoices inv
      	where inv.entry_id = entries.id and length(inv.invoice_number) > 0)
  	SQL
  end

  def down
  	execute "update entries set commercial_invoice_numbers = null" 
  end
end
