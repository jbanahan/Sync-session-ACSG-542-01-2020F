module ValidatesBrokerInvoice
  include ValidatesEntityChildren

  def module_chain
    [CoreModule::ENTRY, CoreModule::BROKER_INVOICE]
  end

  def child_objects entry
    entry.broker_invoices
  end

  def module_chain_entities invoice
    {CoreModule::ENTRY => invoice.entry, CoreModule::BROKER_INVOICE => invoice}
  end
end