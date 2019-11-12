# -*- SkipSchemaAnnotations

class ValidationRuleInvoiceLineMidFirstSale < BusinessValidationRule
  include ValidatesFieldFormat

  def run_validation entry
    importer_system_code = rule_attributes['importer']
    raise "No importer specified" unless importer_system_code.present?
    importer = Company.where(system_code: importer_system_code).first
    raise "Invalid importer system code" unless importer.present?

    mid_xrefs = Set.new(DataCrossReference.hash_for_type(DataCrossReference::ENTRY_MID_VALIDATIONS, company_id: importer.id).keys.map &:strip)

    return nil unless mid_xrefs.size > 0
    return nil unless entry.commercial_invoices.size > 0

    errors = []

    entry.commercial_invoices.each do |invoice|
      next if invoice.commercial_invoice_lines.blank?

      invoice.commercial_invoice_lines.each do |line|
        next unless line.mid.present?

        if mid_xrefs.include?(line.mid)
          errors << "PO #{line.po_number} and MID # #{line.mid} should have first sale data." unless (line.first_sale == true || line.first_sale == nil)
        end
      end
    end

    errors
  end

end