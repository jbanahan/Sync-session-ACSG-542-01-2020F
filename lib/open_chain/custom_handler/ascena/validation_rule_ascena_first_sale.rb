module OpenChain; module CustomHandler; module Ascena; class ValidationRuleAscenaFirstSale < BusinessValidationRule

  def run_validation entry
    # What we need to do here is ensure that every single invoice line on the entry that has an MID that 
    # matches one of the MIDs in their MID list (xref'ed type) has first sale data.
    mids = Set.new DataCrossReference.hash_for_type(DataCrossReference::ASCE_MID).keys.map(&:upcase)

    errors = []
    entry.commercial_invoices.each do |i|
      i.commercial_invoice_lines.each do |l|
        next if l.mid.blank?

        if mids.include?(l.mid.upcase) && invalid_first_sale_data?(l)
          errors << "Invoice # #{i.invoice_number} / Line # #{l.line_number} must have Value Appraisal Method and Contract Amount set."
        end
      end
    end

    errors.length > 0 ? errors.uniq.join("\n") : nil
  end

  def invalid_first_sale_data? line
    line.value_appraisal_method.try(:upcase) != "F" || line.contract_amount.to_f == 0
  end

end; end; end; end