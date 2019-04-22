# -*- SkipSchemaAnnotations

# This validation rule checks that the sum of the duty on the commercial invoices
# (including cotton fee, hmf, mpf) matches the amount reported at the entry header.
# 
# This rule essentially catches and reports a bug in Kewill.  If you roll up a 7501
# the prorated values it calculates back to the individual commercial invoice lines
# do not always sum out to equal the total value it calculated for the entry.
#
# Often times, the amounts are off by a couple cents due to rounding issues in Kewill's 
# code.
class ValidationRuleEntryDutyTaxesMatchSummary < BusinessValidationRule
  include ActionView::Helpers::NumberHelper

  def run_validation entry
    errors = []
    cotton_fee_sum = BigDecimal("0")
    hmf_sum = BigDecimal("0")
    mpf_sum = BigDecimal("0")
    duty_sum = BigDecimal("0")

    entry.commercial_invoices.each do |invoice|
      invoice.commercial_invoice_lines.each do |line|
        cotton_fee_sum += non_nil_value(line.cotton_fee)
        hmf_sum += non_nil_value(line.hmf)
        mpf_sum += non_nil_value(line.prorated_mpf)
        duty_sum += non_nil_value(line.total_duty)
      end
    end

    if duty_sum != non_nil_value(entry.total_duty)
      errors << "Invoice Tariff duty amounts should equal the 7501 Total Duty amount #{number_to_currency(entry.total_duty)} but it was #{number_to_currency(duty_sum)}."
    end

    if mpf_sum != non_nil_value(entry.mpf)
      errors << "Invoice Line MPF amount should equal the 7501 MPF amount #{number_to_currency(entry.mpf)} but it was #{number_to_currency(mpf_sum)}."
    end

    if hmf_sum != non_nil_value(entry.hmf)
      errors << "Invoice Line HMF amount should equal the 7501 HMF amount #{number_to_currency(entry.hmf)} but it was #{number_to_currency(hmf_sum)}."
    end

    if cotton_fee_sum != non_nil_value(entry.cotton_fee)
      errors << "Invoice Line Cotton Fee amount should equal the 7501 Cotton Fee amount #{number_to_currency(entry.cotton_fee)} but it was #{number_to_currency(cotton_fee_sum)}."
    end

    errors
  end

  def non_nil_value value
    value.nil? ? BigDecimal("0") : value
  end
end