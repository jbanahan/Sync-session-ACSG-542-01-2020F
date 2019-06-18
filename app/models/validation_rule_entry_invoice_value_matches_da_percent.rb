# -*- SkipSchemaAnnotations

class ValidationRuleEntryInvoiceValueMatchesDaPercent < BusinessValidationRule
  
  include ValidatesCommercialInvoice

  def run_child_validation invoice
    da_total = invoice.commercial_invoice_lines.inject(0) do |acc, nxt| 
      adj = nxt.adjustments_amount
      adj ? acc + adj : acc
    end    
    target_rate = rule_attributes["adjustment_rate"]
    calc_rate = (BigDecimal(100) * da_total) / invoice.invoice_value_foreign
    unless (target_rate - calc_rate).abs < 0.01
      "Invoice #{invoice.invoice_number} has a DA amount that is #{sprintf('%.2f', calc_rate)}% of the total, expected #{sprintf('%.2f', target_rate)}%."
    end
  end
end
