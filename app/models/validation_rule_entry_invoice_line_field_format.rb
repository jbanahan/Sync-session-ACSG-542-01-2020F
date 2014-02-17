#run a field format validation on every invoice line on the entry and fail if ANY line fails the test
class ValidationRuleEntryInvoiceLineFieldFormat < BusinessValidationRule
  def should_skip? entry
    c_hash = build_search_criterion_hash
    entry.commercial_invoice_lines.each do |cil|
      return false if matches_all_criteria? c_hash, cil
    end
    true # nothing matched all the criteria, so skip
  end
  def run_validation entry
    attrs = self.rule_attributes
    c_hash = build_search_criterion_hash
    mf = ModelField.find_by_uid attrs['model_field_uid']
    reg = attrs['regex']
    entry.commercial_invoice_lines.each do |cil|
      next unless matches_all_criteria? c_hash, cil #don't consider lines that don't match search critera
      val = mf.process_export(cil,nil,true)
      next if attrs['allow_blank'] && val.blank?
      if !val.to_s.match(reg)
        return "All #{mf.label} values do not match '#{reg}' format."      
      end
    end
    nil
  end

  private
  def build_search_criterion_hash
    c_hash = {Entry=>[],CommercialInvoice=>[],CommercialInvoiceLine=>[]}
    self.search_criterions.each do |sc|
      ary = c_hash[sc.core_module.klass]
      raise "Unexpected Core Module #{sc.core_module} for search criterion id #{sc.id}" if ary.nil?
      ary << sc
    end
    c_hash
  end
  def matches_all_criteria? c_hash, ci_line
    ent = ci_line.entry
    c_hash[Entry].each do |sc|
      return false unless sc.test?(ent)
    end
    ci = ci_line.commercial_invoice
    c_hash[CommercialInvoice].each do |sc|
      return false unless sc.test?(ci)
    end
    c_hash[CommercialInvoiceLine].each do |sc|
      return false unless sc.test?(ci_line)
    end
    true
  end
end
