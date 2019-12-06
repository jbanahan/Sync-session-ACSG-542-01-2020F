
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
    XlsxBuilder.numeric_column_to_alphabetic_column(suffix - 1)
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

  def has_duty_charges? invoice_snapshot
    # Canada doesn't actually put duty on the brokerage invoices...so what we're going to do is just assume the first invoice covers duty
    # We can determine if this is the first invoice by seeing if the suffix is blank or not.
    invoice_number = mf(invoice_snapshot, :bi_invoice_number)

    # Fenix invoice numbers look like this XXX-XXXX-XX when they are follow up invoices..so basically...if there's only 2 hyphens
    # the invoice, then we can assume it's the primary invoice
    !invoice_number.match?(/^[^\-]+-[^\-]+-[^\-]+$/)
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
      "22" => "G740",
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

end; end; end; end;
