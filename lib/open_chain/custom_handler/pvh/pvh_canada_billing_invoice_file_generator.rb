
require 'open_chain/custom_handler/pvh/pvh_billing_file_generator_support'

module OpenChain; module CustomHandler; module Pvh; class PvhCanadaBillingInvoiceFileGenerator
  include OpenChain::CustomHandler::Pvh::PvhBillingFileGeneratorSupport

  def generate_and_send_duty_charges(entry_snapshot, invoice_snapshot, invoice)
    invoice_date = mf(invoice_snapshot, :bi_invoice_date)
    invoice_amount = mf(invoice_snapshot, :bi_invoice_total)
    credit_invoice = invoice_amount && invoice_amount < 0

    generate_and_send_invoice_xml(invoice, invoice_snapshot, "DUTY", invoice_number(entry_snapshot, invoice_snapshot, "DUTY")) do |details|
      # What's happening here is that we're assembing the actual invoice keys and charges that need to be used because there's not necessarily
      # a 1-1 mapping between the Commercial Invoice lines and the billing file.  We're summing the charge amounts for each key
      # and then will send them in a single InvoiceLineItem element
      invoice_line_item_charges = Hash.new { |h, k| h[k] = {} }

      # Duty needs to come from the the actual commercial invoice line / tariff data since PVH wants it broken out to the line level..
      json_child_entities(entry_snapshot, "CommercialInvoice") do |invoice_snapshot|
        json_child_entities(invoice_snapshot, "CommercialInvoiceLine") do |line_snapshot|
          charges = duty_charges_for_line(line_snapshot)
          next unless charges.size > 0

          key = find_invoice_line_data(entry_snapshot, invoice_snapshot, line_snapshot)
          total_line_charges = invoice_line_item_charges[key]

          charges.each_pair do |uid, amount|
            # If we're generating a credit invoice, we need to multiply the actual duty amounts by negative 1 to get the credit values.
            amount = (amount * -1) if credit_invoice

            total_line_charges[uid] ||= BigDecimal("0")
            total_line_charges[uid] += amount
          end
        end
      end

      invoice_line_item_charges.each_pair do |key, charges|
        # Each key represents a new invoice line...each charge is a specific charge element in that line
        invoice_line = generate_invoice_line_item(details, "Manifest Line Item", key.item_number, master_bill: key.bill_number,
                          container_number: key.container_number, order_number: key.order_number, part_number: key.part_number)
        charges.each_pair do |uid, amount|
          add_invoice_line_charge invoice_line, invoice_date, amount, duty_gtn_charge_code_map[uid], "CAD"
        end
      end
    end
  end

  def duty_invoice_number entry_snapshot, invoice_snapshot
    inv = mf(entry_snapshot, :ent_entry_num)
    suffix = alphabetic_billing_suffix(mf(invoice_snapshot, :bi_suffix))
    inv += suffix unless suffix.blank?

    inv
  end

  def alphabetic_billing_suffix suffix
    return nil if suffix.blank?
    # Just use the same algorithm for determing the A-Z column index to determine the suffix to use
    # 1 will be the first suffix, which we want to map to A, hence subtracting 1.
    XlsxBuilder.numeric_column_to_alphabetic_column(suffix.to_i - 1)
  end

  def duty_charges_for_line line_snapshot
    charges = {}
    total_duty = mf(line_snapshot, :cil_total_duty)
    charges[:cil_total_duty] = total_duty if total_duty && total_duty.nonzero?

    gst_amount = json_child_entities(line_snapshot, "CommercialInvoiceTariff").map {|t| mf(t, :ent_gst_amount)}.compact.sum
    charges[:ent_gst_amount] = gst_amount if gst_amount && gst_amount.nonzero?

    charges
  end

  def duty_gtn_charge_code_map
    {
      cil_total_duty: "C530",
      ent_gst_amount: "0023"
    }
  end

  # This method determines if the current invoice has any duty that needs to be sent for it...
  def has_duty_charges? invoice_snapshot
    # We're going to assume that every invoice for Canada which includes brokerage should also include duty.
    # This is because the ONLY thing Canada bills PVH for routinely is brokerage (and the service tax (GST) on the brokerage).
    # Therefore duty never actually appears on the the brokerage invoice (as it does in the US - as an informal invoice line (.ie it has no value)).
    # There are some other changes that are occasionally added, so if they're on an invoice by themselves, don't send duty.

    # To accomodate this issue for cases where we may have to back out and resend duty (like when the initial entry information is incorrect
    # the first time the file was sent), we're just going to assume then that every invoice issued (whether postive or negative) should
    # include duty.

    # The implecations of this for Canada are that every single invoice that has brokerage billed, will send duty amounts.
    # This means that if duty needs to be resent for any reason to GTN, the invoice that contained brokerage amount should be reversed
    # (which will send a reversal of the brokerage amounts AND the duty amounts) and then re-issued (which will resend a newly
    # calulated set of duty values).

    # Reverse and rebill is generally how you should resolve cases where PVH calls out that not all the lines on the Order
    # were billed.  This happens because the entry data (as keyed or sent in the commercial invoices), did not fully match the
    # ASN.  Generally, the ASN has more lines than the invoice when this occurs.  The person keying the entry must correct the
    # entry lines to macth the ASN.  Then accounting should reverse the brokerage invoice and rebill it.
    json_child_entities(invoice_snapshot, "BrokerInvoiceLine") do |invoice_line_snapshot|
      charge_code = mf(invoice_line_snapshot, :bi_line_charge_code)
      return true if charge_code.to_s.strip == brokerage_charge_code
    end

    false
  end

  def brokerage_charge_code
    "22"
  end

  def duty_level_codes
    # The right side of this map isn't used, the actual codes are referenced directly in the
    # code writing the duty values.
    {
      "1" => "NOT_A_REAL_GTN_CODE",
      "2" => "NOT_A_REAL_GTN_CODE"
    }
  end

  def container_level_codes
    {
      "31" => "C080",
      "14" => "C080",
      "33" => "0545",
      "255" => "0027",
      brokerage_charge_code => "G740",
      "13" => "974"
    }
  end

  def skip_codes
    []
  end

  def extract_container_level_charges invoice_snapshot
    # PVH "needs" us to split the GST/HST federal tax into it's component pieces
    # GST = Federal VAT, HST = Provincial VAT
    #
    # At this time, the GST is 5% of the brokerage charge...the rest is HST
    # (this may change in the future - it's remained at 5% for a while, if it changes
    # this code will need to be updated)
    charges = super

    # G740 = Brokerage Services
    # 0027 = GST on Brokerage Services
    if !charges["0027"].nil? && !charges["G740"].nil?
      gst, hst = calculate_gst_hst(mf(invoice_snapshot, :bi_invoice_date), charges["G740"], charges["0027"])
      charges["0027"] = gst
      charges["0025"] = hst unless hst.nil?
    end

    charges
  end

  # Invoice date is passed in, since at some point we'll likely need to add logic to
  # use it to determine the federal GST rate.
  def calculate_gst_hst invoice_date, total_taxable_amount, original_gst_amount
    # We can just take the brokerage amount and multiply by 5% - that gets us the
    # "true" GST.  Then we can subtract that "new" GST amount from the original GST
    # to get the calculated HST amount.
    gst = (total_taxable_amount * BigDecimal("0.05")).round(2)
    hst = original_gst_amount - gst
    # Some provinces don't have an HST, if that's the case, the calculated HST above
    # should equal zero after calculating the GST
    if hst.nil? || hst <= 0
      [original_gst_amount, nil]
    else
      [gst, hst]
    end
  end

  def possible_goh_line? line_snapshot
    false
  end

end; end; end; end;
