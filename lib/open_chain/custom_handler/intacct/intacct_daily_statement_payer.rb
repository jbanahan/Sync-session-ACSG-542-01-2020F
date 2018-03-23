# This class marks customs statements as paid in Intacct once they are finalized
# if and only if the brokerage bills in intacct match the statement amounts EXACTLY.
# If they do not, then they need to be cleared manually.

module OpenChain; module CustomHandler; module Intacct; class IntacctDailyStatementPayer
  include ActionView::Helpers::NumberHelper

  def initialize intacct_client: OpenChain::CustomHandler::Intacct::IntacctClient.new
    @intacct_client = intacct_client
  end

  def pay_statement daily_statement
    data = verify_daily_statement_totals(daily_statement)
    if data[:errors].length > 0
      return data[:errors]
    else
      intacct_data = data[:intacct_data]
      result = assemble_payment daily_statement, intacct_data
      return result[:errors] if Array.wrap(result[:errors]).length > 0

      post_payment result[:payment]
      return nil
    end
  rescue => e
    e.log_me ["Daily Statement # #{daily_statement.statement_number}"]
    return [e.message]
  end

  def assemble_payment daily_statement, intacct_data
    # At this point, we need to use the given intacct data to construct an ap_payment and then send/post it to intacct
    # We know that the amounts all match the statement and that if there were any credits (.ie invoices with duty that were reversed)
    # that there should be bills with matching positive amounts.
    # The easiest way to accomplish this is to sort the data by amounts so that the negative values come last, then when a negative amount is
    # encountered, we can find the matching positive amount and attach the credit to that debit line.

    sorted_data = intacct_data.sort {|a, b| b[:total_amount] <=> a[:total_amount]}

    # Lets try and keep the payment sorted in the same order as the statement
    payment_lines = Hash.new {|h, k| h[k] = [] }
    billed_lines = Hash.new {|h, k| h[k] = [] }

    errors = []
    payment = nil

    begin 
      sorted_data.each do |data|
        data[:lines].each do |line|
          if line[:amount] > 0
            detail = OpenChain::CustomHandler::Intacct::IntacctXmlGenerator::IntacctApPaymentDetail.new
            detail.bill_record_no = data[:intacct_id]
            detail.bill_line_id = line[:intacct_id]
            detail.bill_amount = line[:amount]

            payment_lines[data[:broker_reference]] << detail

            line[:payment_detail] = detail

            billed_lines[data[:broker_reference]] << line
          else
            # this means we have a credit we need to apply.  Intacct makes you apply a credit against the matching debit line...so find the debit line we created above 
            # in payment line item that is associated with the same entry
            invoice_data = billed_lines[data[:broker_reference]]

            # Raising here primarily to break out of both loops...would actually be a good place for a label jump if ruby supported that.
            raise "Unable to apply credit for Intacct Bill #{data[:invoice_number]} amount of #{number_to_currency line[:amount]}.  No matching debit line found." if invoice_data.nil?

            # Find the line from those we've already generated which has the postive amount matching the credit (which displays as negative) that may not already
            # have been credited.  There's scenarios where due to billing screwups, duty can be billed / credited several times on the same entry
            uncredited_line = invoice_data.find {|l| l[:amount] == (line[:amount] * -1) && l[:credited].nil? }
            raise "Unable to apply credit for Intacct Bill #{data[:invoice_number]} amount of #{number_to_currency line[:amount]}.  No matching debit line found." if uncredited_line.nil?            
            
            line_to_credit = uncredited_line[:payment_detail]
            raise "Unable to apply credit for Intacct Bill #{data[:invoice_number]} amount of #{number_to_currency line[:amount]}.  No matching debit line found." if line_to_credit.nil?    

            line_to_credit.credit_bill_record_no = data[:intacct_id]
            line_to_credit.credit_bill_line_id = line[:intacct_id]
            line_to_credit.credit_amount = (line[:amount] * -1)

            # We have to also blank the bill_amount value...I'm not entirely sure WHY this is, but Intacct will only let you 
            # apply line item credits to bill amounts that match.  Not sure why you couldn't apply a credit of $X to a bill line
            # with $Y amount on it, but you can't...maybe it's some sort of dual entry book keeping rule.
            line_to_credit.bill_amount = nil

            uncredited_line[:credited] = true
          end
        end  
      end
    rescue => e
      errors << e.message
    end

    if errors.length == 0
      payment_line_items = []
      daily_statement.daily_statement_entries.each do |dse|
        lines = payment_lines[dse.broker_reference]

        # Sort low to high, so the credits are first
        sorted_lines = lines.sort do |a, b|
          val = a.bill_amount.to_f <=> b.bill_amount.to_f
          val = a.credit_amount.to_f <=> b.credit_amount.to_f if val == 0
          val
        end

        payment_line_items.push *sorted_lines
      end


      # Build ap payment header data
      payment = OpenChain::CustomHandler::Intacct::IntacctXmlGenerator::IntacctApPayment.new
      payment.payment_details = payment_line_items
      payment.financial_entity = "TD Bank Duty"
      payment.payment_method = "EFT"
      payment.vendor_id = intacct_duty_vendor
      payment.document_number = daily_statement.statement_number
      payment.currency = "USD"

      # Use the description (memo) field for the monthly number for monthly statements
      if daily_statement.monthly_statement.nil?
        payment.description = daily_statement.statement_number
        payment.payment_date = daily_statement.paid_date
      else
        monthly_statement = daily_statement.monthly_statement
        payment.description = monthly_statement.statement_number
        payment.payment_date = monthly_statement.paid_date
      end

      # For some reason, a few statements are missing the paid date...in this case, just use final received date as the payemnt date
      if payment.payment_date.nil?
        payment.payment_date = daily_statement.final_received_date

        # If it's still nil, just use the current date (this is simply just an emergency fall back, there's
        # really no reason we need to fail simply because a paid date is missing)
        if payment.payment_date.nil?
          payment.payment_date = Time.zone.now.in_time_zone("America/New_York").to_date
        end
      end
    end

    {payment: payment, errors: errors}
  end

  def verify_daily_statement_totals daily_statement
    # Determine the broker invoice numbers that have duty payments on them (either debits OR credits)
    # We'll then look up those values in intacct and make sure the totals match the amounts 
    # in intacct.  If they do then we can proceed to pay off the bill.
    invoice_data = statement_duty_invoice_numbers(daily_statement)

    # We need to now retrieve the invoice data that's in intacct and verify the total against the statement total
    intacct_data = retrieve_intacct_bill_data invoice_data

    # From this point, we need to do the following things
    errors = validate_broker_invoices_in_intacct invoice_data, intacct_data
    
    errors.push *validate_statement_amounts(daily_statement, invoice_data, intacct_data)

    {intacct_data: intacct_data, errors: errors}
  end

  private

    def post_payment payment
      #@intacct_client.post_payment 'vfc', payment
      nil
    end

    def validate_broker_invoices_in_intacct invoice_data, intacct_data
      errors = []
      invoice_data.each do |inv_data|
        intacct_bill = intacct_data.find { |d| d[:invoice_number] == inv_data[:invoice_number] }
        # Validate that each broker invoice is present in the intacct data 
        if intacct_bill.nil?
          errors << "Invoice # #{inv_data[:invoice_number]} is missing from Intacct."
        else
          # Validate that each invoice returned from intacct has not already been paid
          if intacct_bill[:paid] == true
            errors << "Invoice # #{inv_data[:invoice_number]} has already been paid in Intacct."
          # Validate that the duty amount matches the invoice
          elsif intacct_bill[:total_amount] != inv_data[:duty_total]
            errors << "Invoice # #{inv_data[:invoice_number]} shows #{number_to_currency(inv_data[:duty_total])} duty in VFI Track vs. #{number_to_currency(intacct_bill[:total_amount])} in Intacct."
          end
        end
      end

      errors
    end

    def statement_duty_invoice_numbers statement
      broker_invoice_data = []

      statement.daily_statement_entries.each do |dse|
        entry = dse.entry
        # If there's a missing entry for the daily statement, then 
        # it's going to reflect in the statement totals being off, so we can just
        # rely on that fact to catch the imbalance and reject the statement.
        if entry
          broker_invoice_data.push *broker_invoice_data(entry, dse)
        end
      end

      broker_invoice_data
    end

    def broker_invoice_data entry, dse
      invoice_duty_amounts = []

      entry.broker_invoices.each do |bi|
        # Duty Billing is the ONLY thing we care about here...so we ONLY want to pull invoices
        # that have duty lines billed on them.
        lines = bi.broker_invoice_lines.find_all {|l| duty_charge_code? l.charge_code }
        if lines.length > 0
          duty_total = lines.inject(BigDecimal("0")) {|total, line| total + line.charge_amount if line.charge_amount }

          invoice_duty_amounts << {broker_reference: entry.broker_reference, invoice_number: bi.invoice_number, duty_total: duty_total}
        end
      end

      invoice_duty_amounts
    end

    def validate_statement_amounts statement, invoice_data, intacct_data
      errors = []
      # Validate that the total listed on the daily statement matches what's on broker invoices and in intacct
      per_entry_invoice_sums = sum_duty_per_entry(invoice_data)
      per_entry_intacct_sums = sum_duty_per_bill(intacct_data)

      statement.daily_statement_entries.each do |dse|
        invoice_total = per_entry_invoice_sums[dse.broker_reference]
        intacct_total = per_entry_intacct_sums[dse.broker_reference]

        if invoice_total.nil?
          errors << "File # #{dse.broker_reference} has no broker invoice information in VFI Track."
        elsif intacct_total.nil?
          errors << "File # #{dse.broker_reference} has no Accounts Payable Bills found in Intacct."
        elsif invoice_total[:duty_total] != dse.total_amount
          errors << "File # #{dse.broker_reference} shows #{number_to_currency(invoice_total[:duty_total])} billed in VFI Track but #{number_to_currency(dse.total_amount)} on the statement."
        elsif intacct_total[:duty_total] != dse.total_amount
          errors << "File # #{dse.broker_reference} shows #{number_to_currency(intacct_total[:duty_total])} billed in Intacct but #{number_to_currency(dse.total_amount)} on the statement."
        end
      end
      errors
    end

    def sum_duty_per_entry invoice_data
      duty_per_entry = {}
      invoice_data.each do |d|
        duty_per_entry[d[:broker_reference]] ||= {invoice_numbers: [], duty_total: BigDecimal("0")}

        duty_per_entry[d[:broker_reference]][:invoice_numbers] << d[:invoice_number]
        duty_per_entry[d[:broker_reference]][:duty_total] += d[:duty_total]
      end

      duty_per_entry
    end

    def sum_duty_per_bill intacct_data
      duty_per_bill = {}
      intacct_data.each do |d|
        duty_per_bill[d[:broker_reference]] ||= {invoice_numbers: [], duty_total: BigDecimal("0")}

        duty_per_bill[d[:broker_reference]][:invoice_numbers] << d[:invoice_number]
        duty_per_bill[d[:broker_reference]][:duty_total] += d[:total_amount]
      end

      duty_per_bill
    end

    def duty_charge_code? code
      ['0001'].include? code
    end

    def retrieve_intacct_bill_data invoice_data
      return [] if invoice_data.blank?
      
      bill_numbers = invoice_data.map {|d| "'#{@intacct_client.sanitize_query_parameter_value d[:invoice_number]}'" }.join(",")
      ap_bill_entities = @intacct_client.list_objects 'vfc', 'APBILL', "VENDORID = '#{intacct_duty_vendor}' AND RECORDID IN (#{bill_numbers})", fields: ["RECORDNO"]
      ap_bill_ids = extract_intacct_bill_ids(ap_bill_entities)

      # We need to pull the bill lines because the payment we'll eventually issue in Intacct requires indicating which bill lines are being paid, not just the bills
      # themselves.  Unfortunately, the list query cannot return line items, so we need to first query using the bill number (.id record id) and then do a read query
      # with the internal intacct keys.
      bills = @intacct_client.read_object 'vfc', 'APBILL', ap_bill_ids

      # We now have a series of xml entities, we should parse out the values we requested into hashes.
      intacct_data = []
      bills.each do |bill|
        intacct_data << parse_bill_response(bill)
      end
      intacct_data
    end

    def extract_intacct_bill_ids list_response
      ids = []
      list_response.each do |r|
        ids << r.text("RECORDNO")
      end

      ids
    end

    def parse_bill_response bill
      data = {}
      data[:intacct_id] = bill.text("RECORDNO").to_i
      data[:invoice_number] = bill.text("RECORDID")
      data[:total_amount] = BigDecimal(bill.text("TOTALENTERED"))
      data[:total_due] = BigDecimal(bill.text("TOTALDUE"))
      data[:paid] = !bill.text("WHENPAID").to_s.blank?

      data[:lines] = []

      REXML::XPath.each(bill, "APBILLITEMS/apbillitem") do |item|
        line = {}
        line[:intacct_id] = item.text("RECORDNO").to_i
        line[:amount] = BigDecimal(item.text("AMOUNT"))
        # All duty line items will carry the broker reference number as the class intacct dimension
        data[:broker_reference] = item.text("CLASSID")

        data[:lines] << line
      end
      data
    end

    def intacct_duty_vendor
      "VU160"
    end

end; end; end; end