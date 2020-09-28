require 'open_chain/custom_handler/ascena/abstract_ascena_billing_invoice_file_generator'

module OpenChain; module CustomHandler; module Ascena; class AscenaBillingInvoiceFileGenerator < OpenChain::CustomHandler::Ascena::AbstractAscenaBillingInvoiceFileGenerator
  attr_reader :ci_po_numbers

  def generate_and_send entry_snapshot_json
    # Don't even bother trying to send anything if there are failing business rules...
    # There needs to be a rule in place to ensure that the Product Line (aka Brand) field
    # is populated with correct data...if it's not, then the org codes below won't match up.
    return if mf(entry_snapshot_json, "ent_failed_business_rules").present?

    @ci_po_numbers = any_ci_po_numbers? entry_snapshot_json

    # find all the broker invoices, then we can determine which one actually has been billed or not.
    broker_invoice_snapshots = json_child_entities entry_snapshot_json, "BrokerInvoice"

    return if broker_invoice_snapshots.length == 0

    entry = find_entity_object(entry_snapshot_json)
    return if entry.nil?

    # Lock the entry entirely because of how we have to update the broker references associated with the entry
    # and the way the kewill entry parser has to copy the broker invoice data across from an old broker invoice record
    # to a new one.
    Lock.with_lock_retry(entry) do
      trading_partners = [DUTY_SYNC, BROKERAGE_SYNC, DUTY_CORRECTION_SYNC]
      unsent_invoices(entry, broker_invoice_snapshots, trading_partners).each_pair do |invoice_number, invoice_data|
        generate_invoice(entry_snapshot_json, invoice_data, entry) do |file_data, sync_record|
          cust_num = entry_snapshot_json["entity"]["model_fields"]["ent_cust_num"]
          send_file(file_data, sync_record, file_prefix(cust_num), invoice_number: invoice_number,
                                                                   duty_file: duty_sync_type?(sync_record.trading_partner))
          sync_record.sent_at = Time.zone.now
          sync_record.confirmed_at = sync_record.sent_at + 1.minute
          sync_record.save!
        end
      end
    end

    nil
  end

  def any_ci_po_numbers? entry_snapshot_json = nil
    json_child_entities(entry_snapshot_json, "CommercialInvoice", "CommercialInvoiceLine").any? do |inv_line_json|
      mf(inv_line_json, "cil_po_number").present?
    end
  end

  def calculate_duty_amounts entry_snapshot
    invoice_lines = json_child_entities entry_snapshot, "CommercialInvoice", "CommercialInvoiceLine"

    po_duty = Hash.new do |h, k|
      h[k] = BigDecimal("0")
    end

    invoice_lines.each do |line|
      po_number = mf(line, "cil_po_number")
      po_duty[po_number] += BigDecimal(mf(line, "cil_total_duty_plus_fees"))
    end

    po_duty
  end

  def po_organization_code code
    # Catherines = 7218
    # Dress Barn = 221
    # Justice = 151
    # Lane Bryant = 7220
    # Maurices = 218
    xrefs = {"CATHERINES" => "7218", "CA" => "7218", "DRESS BARN" => "221", "DB" => "221", "JUSTICE" => "151", "JST" => "151",
             "LANE BRYANT" => "7220", "LB" => "7220", "MAURICES" => "218", "MAU" => "218"}
    xrefs[code.to_s.strip.upcase]
  end

  def po_organization_ids entry_snapshot
    po_numbers = {}
    invoice_lines = json_child_entities entry_snapshot, "CommercialInvoice", "CommercialInvoiceLine"

    invoice_lines.each do |line|
      po_number = mf(line, "cil_po_number")
      brand_code = po_organization_code(mf(line, "cil_product_line"))

      po_numbers[po_number] = brand_code unless po_number.blank? || brand_code.blank?
    end

    po_numbers
  end

 end; end; end; end
