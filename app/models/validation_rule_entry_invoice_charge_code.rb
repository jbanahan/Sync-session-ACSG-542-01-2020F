class ValidationRuleEntryInvoiceChargeCode < BusinessValidationRule
  
  def run_validation entry
    all_codes = Hash.new(0)
    entry.broker_invoice_lines.each { |line| all_codes[line.charge_code] += line.charge_amount }
    white_list = rule_attributes['charge_codes']
    invalid_codes = []
    all_codes.each do |k,v| 
      unless v.zero? 
        invalid_codes << k if not white_list.include? k
      end
    end
    if invalid_codes.presence
      "The following invalid charge codes were found: #{invalid_codes.join(', ')}." 
    end
  end
end