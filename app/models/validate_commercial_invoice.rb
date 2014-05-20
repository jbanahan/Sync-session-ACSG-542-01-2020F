class ValidateCommercialInvoice < BusinessValidationRule

  def run_validation(invoice)
    validate_invoice_date(invoice)
  end

  def validate_invoice_date(invoice)
    raise "No invoice found." if invoice.blank?
    raise "No invoice date has been set." if invoice.invoice_date.blank?
    return nil
  end

end