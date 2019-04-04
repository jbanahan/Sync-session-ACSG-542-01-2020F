require 'open_chain/custom_handler/pvh/pvh_billing_file_generator_support'

module OpenChain; module CustomHandler; module Pvh; class PvhUsBillingInvoiceFileGenerator
  include OpenChain::CustomHandler::Pvh::PvhBillingFileGeneratorSupport

  def generate_and_send_duty_charges(entry_snapshot, invoice_snapshot, invoice)
    invoice_date = mf(invoice_snapshot, :bi_invoice_date)
    currency = mf(invoice_snapshot, :bi_currency)

    invoice_amount = mf(invoice_snapshot, :bi_invoice_total)
    credit_invoice = invoice_amount && invoice_amount < 0

    hmf_offsets = calculate_hmf_offsets(entry_snapshot)

    generate_and_send_invoice_xml(invoice, invoice_snapshot, "DUTY", invoice_number(entry_snapshot, invoice_snapshot, "DUTY")) do |details|
      # Duty needs to come from the the actual commercial invoice line / tariff data since PVH wants it broken out to the line level..
      invoice_lines = json_child_entities(entry_snapshot, "CommercialInvoice", "CommercialInvoiceLine")

      # What's happening here is that we're assembing the actual invoice keys and charges that need to be used because there's not necessarily
      # a 1-1 mapping between the Commercial Invoice lines and the billing file.  We're summing the charge amounts for each key
      # and then will send them in a single InvoiceLineItem element
      invoice_line_item_charges = Hash.new do |h, k|
        h[k] = {}
      end

      invoice_lines.each do |line_snapshot|
        charges = duty_charges_for_line(line_snapshot, hmf_offsets)
        next unless charges.size > 0

        key = find_invoice_line_key(entry_snapshot, line_snapshot)
        total_line_charges = invoice_line_item_charges[key]


        charges.each_pair do |uid, amount|
          # If we're generating a credit invoice, we need to multiply the actual duty amounts by negative 1 to get the credit values.
          amount = (amount * -1) if credit_invoice

          total_line_charges[uid] ||= BigDecimal("0")
          total_line_charges[uid] += amount
        end
      end

      invoice_line_item_charges.each_pair do |key, charges|
        # Each key represents a new invoice line...each charge is a specific charge element in that line
        invoice_line = generate_invoice_line_item(details, "Manifest Line Item", key.item_number, master_bill: key.bill_number,
                          container_number: key.container_number, order_number: key.order_number, part_number: key.part_number)
        charges.each_pair do |uid, amount|
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

  def duty_charges_for_line line_snapshot, hmf_offsets
    charges = {}
    [:cil_total_duty, :cil_hmf, :cil_prorated_mpf, :cil_cotton_fee, :cil_add_duty_amount, :cil_cvd_duty_amount].each do |uid|
      charge = mf(line_snapshot, uid)
      if charge && charge.nonzero?
        if uid == :cil_hmf
          offset = hmf_offsets[record_id(line_snapshot)]
          charge += offset if offset
        end

        charges[uid] = charge 
      end
      
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

  # What we're doing here is determining if the individual line level hmf values total out to the sum value.
  # In a world where Kewill's software does prorations correctly, we wouldn't have to worry about this but
  # as it is, we're not getting totally correct prorations at the line level and the lines don't sum out to the totals.
  #
  # Thus, we're going to take the difference of the total and the line sum and add the difference back into the line
  # level a penny at a time for every line that has hmf.
  #
  # The return value will be a hash of the line level ids to the offset value required for each commercial invoice line.
  def calculate_hmf_offsets entry_snapshot
    total_hmf = mf(entry_snapshot, :ent_hmf)

    return {} if total_hmf.nil? || total_hmf.zero?

    hmf_line_sum = BigDecimal("0")
    lines_with_hmf = {}

    json_child_entities(entry_snapshot, "CommercialInvoice", "CommercialInvoiceLine") do |line|
      line_hmf = mf(line, :cil_hmf)
      if line_hmf && line_hmf.nonzero?
        lines_with_hmf[record_id(line)] = BigDecimal("0")
        hmf_line_sum += line_hmf
      end
    end

    difference = total_hmf - hmf_line_sum

    return {} if difference.zero?

    # If the difference is less than zero, then the line sum was larger than the total, we need to subtract from the 
    # lines.  Greater than zero means the total was larger than the line sum and we need to add value back into the lines.
    loop_addend = difference < 0 ? BigDecimal("0.01") : BigDecimal("-0.01")

    loop do 
      json_child_entities(entry_snapshot, "CommercialInvoice", "CommercialInvoiceLine") do |line|
        record_id = record_id(line)
        offset = lines_with_hmf[record_id]
        next if offset.nil?

        lines_with_hmf[record_id] = (offset + (loop_addend * -1))
        difference += loop_addend
        break if difference.zero?
      end
      break if difference.zero?
    end

    lines_with_hmf
  end

end; end; end; end;
