module ValidatesCommercialInvoiceLine
  include ValidatesEntityChildren

  def module_chain
    [CoreModule::ENTRY, CoreModule::COMMERCIAL_INVOICE, CoreModule::COMMERCIAL_INVOICE_LINE]
  end

  def child_objects entry
    entry.commercial_invoice_lines
  end

  def module_chain_entities invoice_line
    {CoreModule::ENTRY => invoice_line.entry, CoreModule::COMMERCIAL_INVOICE => invoice_line.commercial_invoice, CoreModule::COMMERCIAL_INVOICE_LINE => invoice_line}
  end

end