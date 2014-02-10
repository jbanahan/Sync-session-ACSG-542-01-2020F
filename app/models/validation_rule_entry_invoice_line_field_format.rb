#run a field format validation on every invoice line on the entry and fail if ANY line fails the test
class ValidationRuleEntryInvoiceLineFieldFormat < BusinessValidationRule
  def run_validation entry
    attrs = self.rule_attributes
    mf = ModelField.find_by_uid attrs['model_field_uid']
    reg = attrs['regex']
    entry.commercial_invoice_lines.each do |cil|
      val = mf.process_export(cil,nil,true)
      next if attrs['allow_blank'] && val.blank?
      if !val.to_s.match(reg)
        return "All #{mf.label} values do not match '#{reg}' format."      
      end
    end
    nil
  end
end
