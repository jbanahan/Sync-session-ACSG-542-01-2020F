module ValidatesCommercialInvoice
  include ValidatesEntityChildren

  def module_chain
    [CoreModule::ENTRY, CoreModule::COMMERCIAL_INVOICE]
  end

  def child_objects entry
    entry.commercial_invoices
  end

  def module_chain_entities invoice
    {CoreModule::ENTRY => invoice.entry, CoreModule::COMMERCIAL_INVOICE => invoice}
  end
end