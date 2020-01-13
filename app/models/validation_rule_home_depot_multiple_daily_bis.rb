# -*- SkipSchemaAnnotations

# This rule is custom to Home Depot.
# Broker Invoice number formats, for Home Depot, are: XXXXXXX, XXXXXX/A, etc.
# Home Depot's system cannot handle more than one Broker Invoice per day so this rule
# checks for multiple Broker Invoices with the same number (excluding the /A) and fails
# if more than one is present.
#
class ValidationRuleHomeDepotMultipleDailyBis < BusinessValidationRule
  def run_validation(entry)
    broker_invoices = {}
    msgs = nil

    entry.broker_invoices.each do |bi|
      bi_date = bi.invoice_date
      split_invoice_number = bi.invoice_number.split('/')
      invoice_number = bi.invoice_number
      broker_invoices[bi_date] ||= {}
      broker_invoices[bi_date][split_invoice_number[0]] ||= []
      broker_invoices[bi_date][split_invoice_number[0]] << invoice_number
    end

    broker_invoices.each do |bi_date|
      multiple_bis = bi_date[1].select { |key, value| value.count > 1 }
      if multiple_bis.present?
        bi_invoice_numbers = multiple_bis.values.flatten.join(', ')
        bi_invoice_date = bi_date[0].to_date.strftime("%m/%d/%Y")
        error_msg = "#{bi_invoice_numbers} were all sent on #{bi_invoice_date}"
        msgs ||= []
        msgs << error_msg
      end
    end

    msgs
  end
end