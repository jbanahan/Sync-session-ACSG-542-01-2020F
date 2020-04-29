module OpenChain; module CustomHandler; module Vandegrift; class KewillEntryStatementValidationRule < BusinessValidationRule
  include ActionView::Helpers::NumberHelper

  def run_validation entry
    return unless entry_has_statement?(entry)
    validation_data = extract_statement_validation_data(entry)

    errors = []
    validate_header_and_line_values(entry: entry, entry_field: :ent_total_duty, invoice_line_field: :cil_total_duty, validation_data: validation_data, validation_field: :duty_amount, errors: errors)
    validate_header_value(entry: entry, entry_field: :ent_total_taxes, validation_data: validation_data, validation_field: :tax_amount, errors: errors)
    validate_header_and_line_values(entry: entry, entry_field: :ent_total_cvd, invoice_line_field: :cil_cvd_duty_amount, validation_data: validation_data, validation_field: :cvd_amount, errors: errors)
    validate_header_and_line_values(entry: entry, entry_field: :ent_total_add, invoice_line_field: :cil_add_duty_amount, validation_data: validation_data, validation_field: :add_amount, errors: errors)

    cotton_valid = validate_header_and_line_values(entry: entry, entry_field: :ent_cotton_fee, invoice_line_field: :cil_cotton_fee, validation_data: validation_data, validation_field: :cotton_fee, errors: errors)
    mpf_valid = validate_header_and_line_values(entry: entry, entry_field: :ent_mpf, invoice_line_field: :cil_prorated_mpf, validation_data: validation_data, validation_field: :mpf_fee, errors: errors)
    hmf_valid = validate_header_and_line_values(entry: entry, entry_field: :ent_hmf, invoice_line_field: :cil_hmf, validation_data: validation_data, validation_field: :hmf_fee, errors: errors)

    # Don't bother validating the total fees field if cotton / mpf / hmf were invalid...it'll always be invalid if any of those were also invalid
    # since they make up a percentage of the totoal fees
    if cotton_valid && mpf_valid && hmf_valid
      validate_header_and_line_values(entry: entry, entry_field: :ent_total_fees, invoice_line_field: :cil_total_fees, validation_data: validation_data, validation_field: :fee_amount, errors: errors)
    end

    # We also need to validate that the amount of duty that was billed to a customer matches what is on the statement
    # Keep in mind that there can be multiple broker invoices if the duty was billed and then backed out and rebilled,
    # so our billed duty amount needs to be a sum of the duty lines on teh broker invoices.

    valid = errors.blank?

    billed_duty = BigDecimal("0")
    entry.broker_invoices.each do |inv|
      billed_duty += inv.total_billed_duty_amount
    end

    if billed_duty.zero? && validation_data[:total_amount].nonzero?
      errors << "The statement indicates a duty amount of '#{number_with_precision(validation_data[:total_amount])}', but no duty has been billed."
    else
      validate_header_value(entry: entry, entry_field: :ent_total_billed_duty_amount, validation_data: validation_data, validation_field: :total_amount, errors: errors)
    end

    # Only bother to validate the total duty / taxes / fees if the other validations went through...there's no point
    # throwing this out if the others failed because then this will also fail and add to the noise on the error message.
    if valid
      validate_header_value(entry: entry, entry_field: :ent_total_duty_taxes_fees_penalties, validation_data: validation_data, validation_field: :total_amount, errors: errors)
    end

    errors.uniq
  end

  def entry_has_statement? entry
    return [2, 3, 6, 7].include?(entry.pay_type) && !entry.daily_statement_entry.nil?
  end

  def extract_statement_validation_data entry
    data = {}
    entry_statement = entry.daily_statement_entry
    data[:duty_amount] = statement_value(entry_statement, :duty_amount)
    data[:tax_amount] = statement_value(entry_statement, :tax_amount)
    data[:fee_amount] = statement_value(entry_statement, :fee_amount)
    data[:cvd_amount] = statement_value(entry_statement, :cvd_amount)
    data[:add_amount] = statement_value(entry_statement, :add_amount)
    data[:cotton_fee] = fee_amount(entry_statement, "56")
    data[:mpf_fee] = fee_amount(entry_statement, "499")
    data[:hmf_fee] = fee_amount(entry_statement, "501")
    data[:total_amount] = statement_value(entry_statement, :total_amount) # This is the sum of all components of the duty

    data
  end

  def statement_value statement, field_name
    statement.public_send(field_name.to_sym)
  end

  def fee_amount statement, fee_code
    fee = statement.daily_statement_entry_fees.find {|f| f.code == fee_code}
    fee.nil? ? BigDecimal("0") : fee.amount
  end

  def value_matches? val1, val2, errors, message
    val1 = val1.presence || BigDecimal("0")
    val2 = val2.presence || BigDecimal("0")

    m = val1 == val2
    errors << message unless m

    m
  end

  def invoice_line_sum entry, model_field
    value = BigDecimal("0")

    entry.commercial_invoices.each do |i|
      i.commercial_invoice_lines.each do |l|
        v = model_field.process_export(l, nil, true)

        value += v if v
      end
    end

    value
  end

  def validate_header_and_line_values entry:, entry_field:, invoice_line_field:, validation_data:, validation_field:, errors:
    valid_value = validate_header_value(entry: entry, entry_field: entry_field, validation_data: validation_data, validation_field: validation_field, errors: errors)
    if valid_value
      line_model_field = ModelField.find_by_uid invoice_line_field
      # Validate the value at the line level too
      invoice_line_value = invoice_line_sum(entry, line_model_field)
      valid_value = value_matches?(invoice_line_value, validation_data[validation_field], errors, "The sum total Commercial Invoice Line #{line_model_field.label(false)} amount of '#{number_with_precision(invoice_line_value, precision: 2)}' does not match the statement amount of '#{number_with_precision(validation_data[validation_field], precision: 2)}'.")
    end

    valid_value
  end

  def validate_header_value entry:, entry_field:, validation_data:, validation_field:, errors:
    entry_model_field = ModelField.find_by_uid entry_field
    entry_value = entry_model_field.process_export(entry, nil, true)
    entry_value = BigDecimal("0") if entry_value.nil? || entry_value.blank?
    value_matches?(entry_value, validation_data[validation_field], errors, "The Entry #{entry_model_field.label(false)} value of '#{number_with_precision(entry_value, precision: 2)}' does not match the statement amount of '#{number_with_precision(validation_data[validation_field], precision: 2)}'.")
  end

end; end; end; end