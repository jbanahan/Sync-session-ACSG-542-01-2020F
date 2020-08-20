# -*- SkipSchemaAnnotations

class ValidationRuleAssistApplied < BusinessValidationRule
  include ValidatesCommercialInvoiceLine

  def run_child_validation(invoice_line)
    importer = find_importer(invoice_line)

    part_number = invoice_line.part_number
    xref = DataCrossReference.find_by(company: importer,
                                      cross_reference_type: 'part_xref',
                                      key: part_number, value: 'true')

    if xref.present?
      if invoice_line.adjusted_value <= 0
        "Invoice line for Part number #{part_number} has no adjusted value"
      end
    end
  end

  def find_importer(invoice_line)
    @find_importer ||= begin
                    importer_system_code = rule_attributes['importer']
                    if importer_system_code
                      importer = Company.find_by(system_code: importer_system_code)
                    else
                      importer = invoice_line&.commercial_invoice&.entry&.importer
                    end

                    raise "Invalid importer system code" if importer.blank?

                    importer
                  end
  end
end