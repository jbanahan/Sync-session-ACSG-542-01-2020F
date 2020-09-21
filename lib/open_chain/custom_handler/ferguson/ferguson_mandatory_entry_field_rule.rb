# Validates the presence of data for fields deemed to be necessary for entry verification XMLs sent to
# Integration Point on behalf of Ferguson (see FergusonEntryVerificationXmlGenerator).  This could be handled with
# a lot of different regular-expression-based business rule, but validating all with one should be more efficient.
module OpenChain; module CustomHandler; module Ferguson; class FergusonMandatoryEntryFieldRule < BusinessValidationRule

  def run_validation(entry)
    errors = []

    # Entry-level field validation.
    if entry.entry_number.blank?
      errors << "Entry Number is required."
    end
    if entry.release_date.nil?
      errors << "Release Date is required."
    end
    if entry.export_country_codes.blank?
      errors << "Country Export Codes is required."
    end
    if entry.entered_value.nil?
      errors << "Total Entered Value is required."
    end
    if entry.total_duty.nil?
      errors << "Total Duty is required."
    end

    # Invoice-level field validation.
    if entry.commercial_invoices.length == 0
      errors << "Entry has no Invoices."
    else
      if entry.commercial_invoices.any? { |ci| ci.currency.blank? }
        errors << "Invoice - Currency is required."
      end
      # Only one invoice needs to have an invoice date.  Sent at header-level.
      if entry.commercial_invoices.all? { |ci| ci.invoice_date.nil? }
        errors << "Invoice - Invoice Date is required."
      end

      # Invoice line-level field validation.
      if entry.commercial_invoices.any? { |ci| ci.commercial_invoice_lines.length == 0 }
        errors << "One or more Invoice has no lines."
      else
        if entry.commercial_invoices.any? { |ci| ci.commercial_invoice_lines.any? { |cil| cil.country_origin_code.blank? } }
          errors << "Invoice Line - Country Origin Code is required."
        end
        if entry.commercial_invoices.any? { |ci| ci.commercial_invoice_lines.any? { |cil| cil.currency.blank? } }
          errors << "Invoice Line - Currency is required."
        end

        # Tariff-level field validation.
        if entry.commercial_invoices.any? { |ci| ci.commercial_invoice_lines.any? { |cil| cil.commercial_invoice_tariffs.length == 0 } }
          errors << "One or more Invoice Line has no tariffs."
        else
          if entry.commercial_invoices.any? { |ci| ci.commercial_invoice_lines.any? { |cil| cil.commercial_invoice_tariffs.any? { |tar| tar.hts_code.blank? } } }
            errors << "Invoice Tariff - HTS Code is required."
          end
          if entry.commercial_invoices.any? { |ci| ci.commercial_invoice_lines.any? { |cil| cil.commercial_invoice_tariffs.any? { |tar| tar.duty_advalorem.nil? } } }
            errors << "Invoice Tariff - Ad Valorem Duty is required."
          end
          if entry.commercial_invoices.any? { |ci| ci.commercial_invoice_lines.any? { |cil| cil.commercial_invoice_tariffs.any? { |tar| tar.entered_value_7501.nil? } } }
            errors << "Invoice Tariff - 7501 Entered Value is required."
          end
        end
      end
    end

    errors.length > 0 ? errors.join(" ") : nil
  end

end; end; end; end