# -*- SkipSchemaAnnotations

class ValidationRuleEntryInvoiceCooMatchesMid < BusinessValidationRule
  include ValidatesCommercialInvoiceLine

  def run_child_validation(invoice_line)
    coo = invoice_line.country_origin_code.to_s
    mid = invoice_line.mid.to_s

    if mid[0..1].downcase != coo.downcase
      "MID '#{mid}' should have a Country of Origin of '#{coo}'."
    end
  end
end
