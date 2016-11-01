module OpenChain; module CustomHandler; module Hm; class ValidationRuleHmInvoiceLineFieldFormat < BusinessValidationRule
  
  def run_validation entry
    positive_regex = rule_attributes["regex"] ? true : false
    pattern = rule_attributes["regex"] || rule_attributes["not_regex"]
    mf = ModelField.find_by_uid(rule_attributes["model_field_uid"])
    bad_lines = check_fields entry, mf, pattern, positive_regex
    generate_output bad_lines, mf, pattern, positive_regex
  end

  private

  def check_fields entry, mf, pattern, positive_regex
    bad_lines = []
    entry.commercial_invoices.each do |ci|
      ci.commercial_invoice_lines.each do |cil|
        field = mf.process_export(cil, nil, true)
        if (!field.to_s.match(pattern) && positive_regex) || (field.to_s.match(pattern) && !positive_regex)
          bad_lines << "Invoice # #{ci.invoice_number}: B3 Sub Hdr # #{cil.subheader_number} / B3 Line # #{cil.customs_line_number} / part #{cil.part_number}"
        end
      end
    end
    bad_lines.uniq
  end

  def generate_output bad_lines, mf, pattern, positive_regex
    header = ["On the following invoice line(s) '#{mf.label}' #{positive_regex ? 'doesn\'t match' : 'matches' } format '#{pattern}':"]
    bad_lines.presence ? header.concat(bad_lines).join("\n") : nil
  end

end; end; end; end