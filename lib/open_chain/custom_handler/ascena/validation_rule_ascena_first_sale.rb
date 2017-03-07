module OpenChain; module CustomHandler; module Ascena; class ValidationRuleAscenaFirstSale < BusinessValidationRule

  def run_validation entry
    # What we need to do here is ensure that every single invoice line on the entry that has an MID that 
    # matches one of the MIDs in their MID list (xref'ed type) has first sale data.
    mids = Set.new DataCrossReference.hash_for_type(DataCrossReference::ASCE_MID).keys.map(&:upcase)

    errors = []
    air = entry.transport_mode_code.to_s == "40"

    entry.commercial_invoices.each do |i|
      # Skip any envoice that ends with NFS (Non-First Sale)
      next if i.invoice_number.to_s.upcase.end_with? "NFS"

      i.commercial_invoice_lines.each do |l|
        next if l.mid.blank?

        # Skip if air entry and line has non-dutiable charges
        next if air && l.non_dutiable_amount.to_f > 0
 
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