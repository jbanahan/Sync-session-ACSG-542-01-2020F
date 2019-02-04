module ValidatesCommercialInvoiceLine
  include ValidatesEntityChildren

  def module_chain
    [CoreModule::ENTRY, CoreModule::COMMERCIAL_INVOICE, CoreModule::COMMERCIAL_INVOICE_LINE]
  end

  def child_objects entry
   objects = []
   entry.commercial_invoices.each do |inv|
     inv.commercial_invoice_lines.each do |line|
       objects << line
     end
   end
   objects
 end

  def module_chain_entities invoice_line
    {CoreModule::ENTRY => invoice_line.commercial_invoice.entry, CoreModule::COMMERCIAL_INVOICE => invoice_line.commercial_invoice, CoreModule::COMMERCIAL_INVOICE_LINE => invoice_line}
  end

end
