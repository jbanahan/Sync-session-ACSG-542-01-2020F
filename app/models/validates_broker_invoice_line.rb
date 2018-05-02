module ValidatesBrokerInvoiceLine
  include ValidatesEntityChildren

  def module_chain
    [CoreModule::ENTRY, CoreModule::BROKER_INVOICE, CoreModule::BROKER_INVOICE_LINE]
  end

  def child_objects entry
    entry.broker_invoice_lines
  end

  def module_chain_entities invoice_line
    {CoreModule::ENTRY => invoice_line.entry, CoreModule::BROKER_INVOICE => invoice_line.broker_invoice, CoreModule::BROKER_INVOICE_LINE => invoice_line}
  end
end