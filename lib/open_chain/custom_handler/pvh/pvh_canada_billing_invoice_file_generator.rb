
require 'open_chain/custom_handler/pvh/pvh_billing_file_generator_support'

module OpenChain; module CustomHandler; module Pvh; class PvhCanadaBillingInvoiceFileGenerator
  include OpenChain::CustomHandler::Pvh::PvhBillingFileGeneratorSupport

  def generate_and_send_duty_charges(entry_snapshot, invoice_snapshot, invoice)
    invoice_date = mf(invoice_snapshot, :bi_invoice_date)

    generate_and_send_invoice_xml(invoice, invoice_snapshot, "DUTY", invoice_number(entry_snapshot, invoice_snapshot, "DUTY")) do |details|
      # Duty needs to come from the the actual commercial invoice line / tariff data since PVH wants it broken out to the line level..
      json_child_entities(entry_snapshot, "CommercialInvoice", "CommercialInvoiceLine") do |line_snapshot|

        charges = duty_charges_for_line(line_snapshot)
        next unless charges.size > 0

        invoice_line = add_invoice_line(details, entry_snapshot, line_snapshot)
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
      "33" => "545",
      "255" => "0027",
      "22" => "G740"
    }
  end

  def skip_codes
    []
  end

end; end; end; end;
