require 'open_chain/custom_handler/pvh/pvh_billing_file_generator_support'

module OpenChain; module CustomHandler; module Pvh; class PvhUsBillingInvoiceFileGenerator
  include OpenChain::CustomHandler::Pvh::PvhBillingFileGeneratorSupport

  def generate_and_send_duty_charges(entry_snapshot, invoice_snapshot, invoice)
    invoice_date = mf(invoice_snapshot, :bi_invoice_date)
    currency = mf(invoice_snapshot, :bi_currency)

    invoice_amount = mf(invoice_snapshot, :bi_invoice_total)
    credit_invoice = invoice_amount && invoice_amount < 0

    generate_and_send_invoice_xml(invoice, invoice_snapshot, "DUTY", invoice_number(entry_snapshot, invoice_snapshot, "DUTY")) do |details|
      # Duty needs to come from the the actual commercial invoice line / tariff data since PVH wants it broken out to the line level..
      invoice_lines = json_child_entities(entry_snapshot, "CommercialInvoice", "CommercialInvoiceLine")
      invoice_lines.each do |line_snapshot|

        charges = duty_charges_for_line(line_snapshot)
        next unless charges.size > 0

        invoice_line = add_invoice_line(details, entry_snapshot, line_snapshot)
        charges.each_pair do |uid, amount|
          # If we're generating a credit invoice, we need to multiply the actual duty amounts by negative 1 to get the credit values.
          amount = (amount * -1) if credit_invoice
          add_invoice_line_charge invoice_line, invoice_date, amount, duty_gtn_charge_code_map[uid], currency
        end
      end
    end
  end

  # For US, we can just use the suffix directly from the invoice itself.
  def duty_invoice_number entry_snapshot, invoice_snapshot
    inv = mf(entry_snapshot, :ent_entry_num)
    suffix = mf(invoice_snapshot, :bi_suffix)
    inv += suffix unless suffix.blank?

    inv
  end

  def duty_charges_for_line line_snapshot
    charges = {}
    [:cil_total_duty, :cil_hmf, :cil_prorated_mpf, :cil_cotton_fee, :cil_add_duty_amount, :cil_cvd_duty_amount].each do |uid|
      charge = mf(line_snapshot, uid)
      charges[uid] = charge if charge && charge.nonzero?
    end

    charges
  end

  def duty_gtn_charge_code_map
    {
      cil_total_duty: "C531",
      cil_hmf: "D503",
      cil_prorated_mpf: "E586",
      cil_cotton_fee: "CTTF1",
      cil_add_duty_amount: "AND2",
      cil_cvd_duty_amount: "COD3"
    }
  end

  def duty_level_codes
    # The right side of this map isn't used, the actual codes are referenced directly in the
    # code writing the duty values.
    {
      "0001" => "NOT_A_GTN_CODE"
    }
  end

  def container_level_codes
    {
      "0044" => "C080", 
      "0082" => "974", 
      "0050" => "0545",
      "0007" => "G740", 
      "0008" => "E063", 
      "0009" => "AFEE", 
      "0191" => "ISF1", 
      "0014" => "E590", 
      "0125" => "175", 
      "0031" => "176",
      "0047" => "120", 
      "0095" => "909"
    }
  end

  def skip_codes
    # 99 is duty direct
    # 0600 is freight direct
    # 0090 is Drawback (which has no commercial invoice data)
    ["0099", "0600", "0090"]
  end

end; end; end; end;
