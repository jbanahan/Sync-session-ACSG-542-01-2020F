# -*- SkipSchemaAnnotations

class ValidationRuleInvoiceNumberMatchesInvoiceLinePO < BusinessValidationRule
  include ValidatesCommercialInvoiceLine

  def run_child_validation(commercial_invoice_line)
    ci_first_eight_digits = commercial_invoice_line.po_number[0..7]
    invoice_first_eight_digits = commercial_invoice_line.commercial_invoice.invoice_number[0..7]

    if ci_first_eight_digits != invoice_first_eight_digits
      "Invoice Line #{commercial_invoice_line.line_number}'s PO number does not match invoice number #{commercial_invoice_line.commercial_invoice.invoice_number}"
    else
      nil
    end
  end
end