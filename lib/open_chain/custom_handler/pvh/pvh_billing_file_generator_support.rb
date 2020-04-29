require 'open_chain/xml_builder'
require 'open_chain/ftp_file_support'
require 'open_chain/entity_compare/comparator_helper'
require 'open_chain/custom_handler/pvh/pvh_entry_shipment_matching_support'

module OpenChain; module CustomHandler; module Pvh; module PvhBillingFileGeneratorSupport
  extend ActiveSupport::Concern
  include OpenChain::XmlBuilder
  include OpenChain::FtpFileSupport
  include OpenChain::EntityCompare::ComparatorHelper
  include OpenChain::CustomHandler::Pvh::PvhEntryShipmentMatchingSupport

  # This is simply a sync record we're going to add to ANY broker invoice we've already generated billing data for
  # We'll then use the more specific sync codes to associate sync records with the actual files we're generating
  # for the Duty files, the brokerage charge files, and the bill of lading level charges.
  PRIMARY_SYNC ||= "PVH BILLING"
  DUTY_SYNC ||= "PVH BILLING DUTY"
  CONTAINER_SYNC ||= "PVH BILLING CONTAINER"

  def generate_and_send entry_snapshot_json
    # Don't even bother trying to send anything if there are failing business rules...
    return unless mf(entry_snapshot_json, "ent_failed_business_rules").blank?

    # find all the broker invoices, then we can determine which one actually has been billed or not.
    broker_invoice_snapshots = json_child_entities entry_snapshot_json, "BrokerInvoice"

    return if broker_invoice_snapshots.length == 0

    return unless all_data_present?(entry_snapshot_json)

    entry = find_entity_object_by_snapshot_values(entry_snapshot_json, broker_reference: :ent_brok_ref, customer_number: :ent_cust_num)
    return if entry.nil?

    # Lock the entry entirely because of how we have to update the broker references associated with the entry
    # and the way the kewill entry parser has to copy the broker invoice data across from an old broker invoice record
    # to a new one.
    Lock.db_lock(entry) do
      unsent_invoices(entry, broker_invoice_snapshots).each do |invoice_data|
        generate_and_send_invoice_files(entry_snapshot_json, invoice_data[:snapshot], invoice_data[:invoice])
      end
    end

    nil
  end

  def all_data_present? entry_snapshot
    all_entry_data_present?(entry_snapshot) && all_invoice_lines_data_present?(entry_snapshot)
  end

  def all_entry_data_present? entry_snapshot
    return false if mf(entry_snapshot, :ent_mbols).blank?

    # Validate we have containers for Ocean shipments
    if Entry.get_transport_mode_codes_us_ca("SEA").include?(mf(entry_snapshot, :ent_transport_mode_code).to_i)
      return false if entry_container_numbers(entry_snapshot).blank?
    end

    # For US entries, we need to have a One USG Date present before we can send the data
    # Operations is not supposed to bill the invoice until One USG is received, this code is just a check
    # to make sure that's enforced and we don't send the billing files until One USG is received.
    one_usg = mf(entry_snapshot, :ent_one_usg_date)
    if one_usg.nil?
      return false if mf(entry_snapshot, :ent_cntry_iso) == "US"
    end

    true
  end

  def all_invoice_lines_data_present? entry_snapshot
    lines = json_child_entities(entry_snapshot, "CommercialInvoice", "CommercialInvoiceLine")
    return false if lines.length == 0

    lines.each do |line|
      return false if mf(line, :cil_po_number).blank? || mf(line, :cil_part_number).blank? || mf(line, :ent_unit_price).blank? || mf(line, :cil_units).blank?
    end

    true
  end

  def generate_and_send_invoice_files(entry_snapshot, invoice_snapshot, invoice)
    # It's possible due to some error conditions that we'll have sent one invoice type for the invoice, but not
    # another type.  So make sure we're not sending the invoice type over and over again.
    if has_duty_charges?(invoice_snapshot) && invoice_type_needs_sending?(invoice, "DUTY")
      sent = false
      if credit_invoice?(invoice_snapshot)
        begin
          sent = generate_and_send_reversal(entry_snapshot, invoice_snapshot, invoice, "DUTY")
        rescue => e
          handle_errored_sends(invoice, "DUTY", e)
          return nil
        end
      end

      begin
        generate_and_send_duty_charges(entry_snapshot, invoice_snapshot, invoice) unless sent
      rescue => e
        handle_errored_sends(invoice, "DUTY", e)
        return nil
      end
    end

    if has_container_charges?(invoice_snapshot) && invoice_type_needs_sending?(invoice, "CONTAINER")
      sent = false
      if credit_invoice?(invoice_snapshot)
        begin
          sent = generate_and_send_reversal(entry_snapshot, invoice_snapshot, invoice, "CONTAINER")
        rescue => e
          handle_errored_sends(invoice, "CONTAINER", e)
          return nil
        end
      end

      begin
        generate_and_send_container_charges(entry_snapshot, invoice_snapshot, invoice) unless sent
      rescue => e
        handle_errored_sends(invoice, "CONTAINER", e)
        return nil
      end
    end

    sync_record = find_or_build_sync_record(invoice, PRIMARY_SYNC)
    sync_record.sent_at = Time.zone.now
    sync_record.confirmed_at = Time.zone.now + 1.minute
    sync_record.failure_message = nil

    sync_record.save!
    nil
  end

  def handle_errored_sends invoice, invoice_type, error
    sync_record = find_or_build_sync_record invoice, invoice_type_xref[invoice_type]
    sync_record.failure_message = error.message
    sync_record.save!
    error.log_me ["Failed to generate #{invoice_type} invoice for Broker Invoice # #{invoice.invoice_number}."]
  end

  def invoice_type_needs_sending? invoice, invoice_type
    trading_partner = invoice_type_xref[invoice_type]
    sr = invoice.sync_records.find { |r| r.trading_partner == trading_partner }
    sr.nil? || sr.sent_at.nil?
  end

  def invoice_number entry_snapshot, invoice_snapshot, invoice_type
    if invoice_type == "DUTY"
      # Implementing classes must implement this method, as the algorithm differs between US and Canada
      inv_num = duty_invoice_number(entry_snapshot, invoice_snapshot)
    elsif invoice_type == "CONTAINER"
      inv_num = container_invoice_number(entry_snapshot, invoice_snapshot)
    else
      raise "Invalid invoice type #{invoice_type}."
    end

    inv_num.to_s.gsub(/[^A-Za-z0-9]/, "")
  end

  def container_invoice_number entry_snapshot, invoice_snapshot
    mf(invoice_snapshot, :bi_invoice_number)
  end

  # Either of these values can be nil or present.  Both should never be nil.
  ContainerBillingKey ||= Struct.new(:bill_number, :container_number)

  def generate_and_send_container_charges(entry_snapshot, invoice_snapshot, invoice)
    # Strip any non-alphanumeric chars..not sure if ever bill using them or not, but PVH appears to have systemic issues if
    # we even have a hyphen in the invoice number, so just be safe and clear it out.
    invoice_number = mf(invoice_snapshot, :bi_invoice_number).gsub(/[^A-Za-z0-9]/, "")
    invoice_date = mf(invoice_snapshot, :bi_invoice_date)
    currency = mf(invoice_snapshot, :bi_currency)
    generate_and_send_invoice_xml(invoice, invoice_snapshot, "CONTAINER", invoice_number) do |details|
      # Extract all the charges and amounts we need to bill on this brokerage invoice
      charges = extract_container_level_charges(invoice_snapshot)

      # Retrieve Shipment Lines for each invoice line
      # Sort them into Top-Level "keys"

      # Prorate charges based on the relative weights of the shipment lines underneath each key
      # Write prorated charges out

      # This method will split the invoice lines according to the method required by the mode of transport / etc
      # The resulting object is a hash that is keyed by the bill number / container value to utilize when sending
      # the data to GT Nexus.  Each value contains an array of InvoiceLineData objects, containing all the lines
      # pertinent to the bill/container key.
      invoice_lines = extract_and_sort_invoice_line_data(entry_snapshot)
      total_proration_value, keyed_proration_sums = generate_proration_sums(invoice_lines)
      prorations = {}

      # Generate the prorations for each charge line
      charges.each_pair do |charge_code, amount|
        prorate_values(keyed_proration_sums, total_proration_value, charge_code, amount, prorations)
      end

      line_counter = 1
      prorations.each_pair do |billing_key, charge_amounts|
        charge_amounts.each_pair do |charge_code, amount|
          added = add_container_line(details, entry_snapshot, billing_key.container_number, invoice_date, amount, charge_code, currency, line_counter, bill_number: billing_key.bill_number)
          line_counter += 1 if added
        end
      end
    end
  end

  def extract_and_sort_invoice_line_data entry_snapshot
    sorted_lines = Hash.new {|h, k| h[k] = [] }
    json_child_entities(entry_snapshot, "CommercialInvoice") do |invoice_snapshot|
      json_child_entities(invoice_snapshot, "CommercialInvoiceLine") do |line_snapshot|
        # The invoice line data lookup also sets the expected bill / container number "keys" to use on the charge outputs
        # So we can just use this value to prorate the amounts over.
        invoice_line_data = find_invoice_line_data(entry_snapshot, invoice_snapshot, line_snapshot)
        sorted_lines[ContainerBillingKey.new(invoice_line_data.bill_number, invoice_line_data.container_number)] << invoice_line_data
      end
    end

    sorted_lines
  end

  def generate_proration_sums invoice_line_data
    proration_sums = Hash.new {|h, k| h[k] = BigDecimal("0") }
    total_weight = BigDecimal("0")

    invoice_line_data.each_pair do |billing_key, invoice_lines|
      Array.wrap(invoice_lines).each do |invoice_line_data|
        if invoice_line_data&.shipment_line&.gross_kgs.to_f > 0
          proration_sums[billing_key] += invoice_line_data&.shipment_line&.gross_kgs
          total_weight += invoice_line_data&.shipment_line&.gross_kgs
        end
      end
    end

    # If no weight was actually entered, but there's only a single billing key, that means there's
    # no ACTUAL proration that needs to be done on the charges...ergo, we can just apply all the proratable value to the single
    # billing key
    if total_weight == 0
      if invoice_line_data.keys.length == 1
        total_weight = BigDecimal("1")
        proration_sums[invoice_line_data.keys.first] = total_weight
      else
        # Raise an error...we have multiple billing units, but none of them have weight amounts so we can't
        # accurately prorate the values.  We COULD prorate evenly...or fall back to volume?
        raise "Unable to calculate proration amounts.  No shipments lines associated with this entry have weights recorded for them."
      end
    end

    [total_weight, proration_sums]
  end

  def ocean_mode? entry_snapshot
    ocean_mode_entry?(mf(entry_snapshot, :ent_transport_mode_code))
  end

  def air_mode? entry_snapshot
    air_mode_entry?(mf(entry_snapshot, :ent_transport_mode_code))
  end

  def truck_mode? entry_snapshot
    truck_mode_entry?(mf(entry_snapshot, :ent_transport_mode_code))
  end

  def ocean_lcl_mode? entry_snapshot
    ocean_mode?(entry_snapshot) && (mf(entry_snapshot, :ent_fcl_lcl).to_s =~ /LCL/i).present?
  end

  HouseContainerKey ||= Struct.new(:house_bill, :container_number)

  def find_containers_by_invoice_number shipments, invoice_number
    return [] if invoice_number.blank?

    containers = Set.new
    shipments.each do |s|
      s.shipment_lines.each do |line|
        if line.invoice_number == invoice_number
          containers << line.container
        end
      end
    end

    containers.to_a.compact
  end

  def unsent_invoices entry, broker_invoice_snapshots
    invoices = []
    broker_invoice_snapshots.each do |bi|
      next unless send_to_gt_nexus?(entry, bi)

      invoice_number = mf(bi, "bi_invoice_number")
      broker_invoice = entry.broker_invoices.find {|inv| inv.invoice_number == invoice_number}

      # It's possible the invoice won't be found because it may have been updated in the intervening time from Kewill
      next if broker_invoice.nil? || broker_invoice.sync_records.find {|s| s.trading_partner == PRIMARY_SYNC && !s.sent_at.nil? }.present?

      invoices << {snapshot: bi, invoice: broker_invoice}
    end

    invoices
  end

  def send_to_gt_nexus? entry, invoice_snapshot
    if entry.canadian?
      # There's no special billing paths for Canada, so just send everything that's billed on those files
      return true
    else
      customer_number = mf(invoice_snapshot, "bi_customer_number").to_s.upcase
      bill_to_name = mf(invoice_snapshot, "bi_to_name").to_s.upcase
      # We do some form of special billing for PVH, in that we bill any Pierpass charges to a separate PVH entity.
      # PVH does not want those charges sent to GTN.  Operations is supposed to only be billing Pierpass to that account,
      # everything else is sent to 'PVH Corp'.  So, we should be able to accept anything billed to that account name.
      # Unfortunately, the bill to customer used for both cases is just "PVH".

      # We also bill PVH under a separate accounts of PVHCA and PVHNE.
      # PVHCA is "special projects" for a team at PVH which they do not want sent to GTN.
      # PVHNE is neckwear and none of that data is in GTN either.
      # Therefore, suppress anything for these two accounts.
      return customer_number == "PVH" && bill_to_name == "PVH CORP"
    end

    return false
  end

  def generate_and_send_reversal(entry_snapshot, invoice_snapshot, invoice, invoice_type)
    original_invoice, invoice_xml_lines = find_and_reverse_original_invoice_xml_lines(entry_snapshot, invoice_snapshot, invoice_type)
    return false if invoice_xml_lines.blank?

    generate_and_send_invoice_xml(invoice, invoice_snapshot, invoice_type, invoice_number(entry_snapshot, invoice_snapshot, invoice_type)) do |details|
      invoice_xml_lines.each do |line|
        details << line
      end
    end

    reversal_sync = original_invoice.sync_records.find {|s| s.trading_partner == reversal_invoice_type(invoice_type) }
    if reversal_sync.nil?
      reversal_sync = original_invoice.sync_records.build trading_partner: reversal_invoice_type(invoice_type)
    end
    reversal_sync.sent_at = Time.zone.now
    reversal_sync.confirmed_at = (Time.zone.now + 1.minute)
    reversal_sync.save!
    true
  end

  class InvoiceLineData
    attr_accessor :bill_number, :container_number, :order_number, :part_number, :item_number, :shipment_line, :invoice_line

    def initialize bill_number, container_number, order_number, part_number, item_number, shipment_line
      @bill_number = bill_number
      @container_number = container_number
      @order_number = order_number
      @part_number = part_number
      @item_number = item_number
      @shipment_line = shipment_line
    end

    def == other_key
      self.bill_number == other_key.bill_number &&
        self.container_number == other_key.container_number &&
        self.order_number == other_key.order_number &&
        self.part_number == other_key.part_number &&
        self.item_number == other_key.item_number &&
        self.shipment_line == other_key.shipment_line
    end

    def eql?(other_key)
      self == other_key
    end

    def hash
      [self.bill_number, self.container_number, self.order_number, self.part_number, self.item_number, self.shipment_line].hash
    end
  end

  def find_invoice_line_data entry_snapshot, invoice_snapshot, line_snapshot
    container_number = mf(line_snapshot, :cil_con_container_number)
    order_number = mf(line_snapshot, :cil_po_number)
    part_number = mf(line_snapshot, :cil_part_number)
    units = mf(line_snapshot, :cil_units)
    invoice_number = mf(invoice_snapshot, :ci_invoice_number)

    shipment_line = find_shipment_line(find_shipments_by_entry_snapshot(entry_snapshot), container_number, order_number, part_number, units, invoice_number: invoice_number)
    raise "Failed to find matching PVH ASN line for Invoice # #{invoice_number}, PO # #{order_number} and Part Number #{part_number} on Entry File # '#{mf(entry_snapshot, :ent_brok_ref)}'." if shipment_line.nil?

    order_line = shipment_line&.order_line
    order_line_number = order_line&.line_number

    container_number, bill_number = container_and_bill_number(entry_snapshot, shipment_line&.container, shipment_line)

    d = InvoiceLineData.new(bill_number, container_number, order_number, part_number, order_line_number, shipment_line)
    d.invoice_line = line_snapshot

    d
  end

  def add_invoice_line_charge parent_element, invoice_date, amount, code, currency
    generate_charge_field parent_element, "Manifest Line Item", code, invoice_date, amount, currency
  end

  def add_container_line parent_element, entry_snapshot, container_number, invoice_date, amount, code, currency, line_counter, bill_number: nil
    return false unless amount && amount.nonzero?

    line_item = generate_invoice_line_item(parent_element, "Container", line_counter, master_bill: bill_number, container_number: container_number)
    generate_charge_field(line_item, "Container", code, invoice_date, amount, currency)
    return true
  end

  def container_and_bill_number entry_snapshot, container, shipment_line
    # Ocean FCL -> Master Bill / Container
    # Ocean LCL -> House Bill / Container
    # Air -> House Bill
    # Truck -> Container

    # For Ocean FCL modes we need to send the Master Bill as the BLNumber
    # For Ocean LCL / Air modes we need to send the House Bill as the BLNumber
    bill_of_lading = nil
    container_number = nil
    if ocean_mode?(entry_snapshot)
      lcl = container&.fcl_lcl.to_s.strip.upcase == "LCL"
      if lcl
        # LCL shipments (in general) will use the house bill...but if there's no house bill, use the master from the ASN
        bill_of_lading = container&.shipment&.house_bill_of_lading
      end
      bill_of_lading = container&.shipment&.master_bill_of_lading if bill_of_lading.blank?
      container_number = container.container_number
    elsif air_mode?(entry_snapshot)
      if shipment_line.nil?
        bill_of_lading = container&.shipment&.house_bill_of_lading
        container_number = bill_of_lading
      else
        bill_of_lading = shipment_line&.shipment&.house_bill_of_lading
        container_number = bill_of_lading
      end
    elsif truck_mode?(entry_snapshot)
      bill_of_lading = container&.shipment&.master_bill_of_lading
      container_number = container.container_number
    end

    [container_number, bill_of_lading]
  end

  def generate_and_send_invoice_xml broker_invoice, broker_invoice_snapshot, invoice_type, invoice_number, &block
    xml, filename = generate_invoice_xml(broker_invoice_snapshot, invoice_type, invoice_number, &block)
    return nil unless xml.present?

    send_invoice_xml(broker_invoice, invoice_type, filename, xml)
    xml
  end

  def send_invoice_xml broker_invoice, invoice_type, filename, xml
    Tempfile.open([File.basename(filename), ".xml"]) do |temp|
      Attachment.add_original_filename_method(temp, filename)
      write_xml(xml, temp)
      temp.rewind

      sync_record = find_or_build_sync_record broker_invoice, invoice_type_xref[invoice_type]

      ftp_sync_file temp, sync_record

      sync_record.sent_at = Time.zone.now
      sync_record.confirmed_at = Time.zone.now + 1.minute
      # If we're updating an existing sync record, there might be a failure message, so clear it now that we have sent the data.
      sync_record.failure_message = nil

      sync_record.save!
    end
  end

  def find_or_build_sync_record broker_invoice, trading_partner
    sr = broker_invoice.sync_records.find {|sr| sr.trading_partner == trading_partner }
    if sr.nil?
      sr = broker_invoice.sync_records.build trading_partner: trading_partner
    end

    sr
  end

  def ftp_credentials
    connect_vfitrack_net("to_ecs/pvh_invoice")
  end

  def reset_data
    found_shipment_lines.clear
  end

  def generate_invoice_xml broker_invoice_snapshot, invoice_type, invoice_number
    # setup/reset any data used for any previous invoice generations
    reset_data

    doc, root = build_xml_document("GenericInvoiceMessage")
    invoice_date = mf(broker_invoice_snapshot, :bi_invoice_date)

    filename = "GI_VANDE_PVH_#{invoice_number}_#{invoice_type}_#{Time.zone.now.strftime("%Y%m%d%H%M%S")}.xml"

    invoice_element, invoice_header, invoice_details = generate_invoice_file_header(root, broker_invoice_snapshot, invoice_number, invoice_date, filename)

    yield invoice_details

    # We need to add the summary / line count element now based on the number of line items present in the details
    lines = REXML::XPath.first(invoice_details, "count(InvoiceLineItem)")
    if lines.to_i > 0
      summary = add_element(invoice_element, "InvoiceSummary")
      add_element(summary, "NumberOfInvoiceLineItems", lines.to_i)

      return [doc, filename]
    else
      # If nothing was actually added to the xml, then return nil
      return nil
    end
  end

  def generate_invoice_file_header root, broker_invoice_snapshot, invoice_number, invoice_date, filename
    transaction_info = add_element(root, "TransactionInfo")
    add_element(add_element(transaction_info, "Sender"), "Code", "VANDEGRIFT")
    add_element(add_element(transaction_info, "Receiver"), "Code", "PVH")
    file = add_element(transaction_info, "File")

    now = Time.zone.now.in_time_zone("America/New_York")
    generate_date_time_elements(add_element(file, "ReceivedTime"), now.strftime("%Y-%m-%d"), now.strftime("%H:%M:%S"))

    original_file = add_element(file, "OriginalFile")
    add_element(original_file, "FileType", "XML")
    add_element(original_file, "FileName", filename)
    add_element(original_file, "MessageType", "GENINV")
    add_element(original_file, "MessageId", now.to_i.to_s)
    add_element(original_file, "ControlNumber", now.to_i.to_s)
    add_element(original_file, "HeaderControlNumber", now.to_i.to_s)

    xml_file = add_element(file, "XMLFile")
    add_element(xml_file, "FileName", filename)
    generate_date_time_elements(add_element(xml_file, "CreateTime"), now.strftime("%Y-%m-%d"), now.strftime("%H:%M:%S"))

    generic_invoices = add_element(root, "GenericInvoices")
    generic_invoice = add_element(generic_invoices, "GenericInvoice")
    generic_invoice.add_attribute("Type", "Broker Invoice")
    add_element(generic_invoice, "Purpose", "Create")

    invoice_header = add_element(generic_invoice, "InvoiceHeader")
    add_element(invoice_header, "InvoiceNumber", invoice_number)
    # Invoice Date is a date object - so it will 8601'ize as YYYY-MM-DD...then just hardcode the rest to 12 noon
    add_element(invoice_header, "InvoiceDateTime", "#{invoice_date.iso8601}T12:00:00")
    [generic_invoice, invoice_header, add_element(generic_invoice, "InvoiceDetails")]
  end

  def generate_invoice_line_item parent_element, level, item_number, master_bill: nil, container_number: nil, order_number: nil, part_number: nil
    line_item = add_element(parent_element, "InvoiceLineItem")
    line_item.add_attribute("Level", level)

    add_element(line_item, "ItemNumber", pad_number(item_number))
    add_element(line_item, "BLNumber", master_bill, allow_blank: false)
    add_element(line_item, "ContainerNumber", container_number, allow_blank: false)
    add_element(line_item, "OrderNumber", order_number, allow_blank: false)
    add_element(line_item, "ProductCode", part_number, allow_blank: false)

    line_item
  end

  def pad_number number, digits: 3, pad_char: "0"
    number = number.to_s
    if number.length < 3
      number = number.rjust(digits, pad_char)
    end

    number
  end

  def generate_charge_field parent_element, level, charge_code, invoice_date, amount, currency
    charge_field = add_element(parent_element, "ChargeField")
    add_element(charge_field, "Level", level)
    type_code = add_element(charge_field, "Type")
    add_element(type_code, "Code", charge_code)
    # We don't actually have time values for when we issue invoices, so just set to noon
    # The ActiveSupport::TimeZone sets either "EDT" or "EST" depending on the time of the year
    generate_date_time_elements(add_element(charge_field, "ChargeDate"), invoice_date.strftime("%Y-%m-%d"), "12:00:00", timezone: "UTC")

    # Technically, all reversals should be handled via the find_and_reverse_original_invoice_xml_lines method, which
    # just builds the xml for the invoice from the existing sent invoice.  However, there WILL be times where that invoice
    # doesn't exist any longer (someone cleared the sync record, somethign screwy happened with billing), so we're going to have to
    # also handle the decrement (credit) case here too.  So if the amount is negative, then just send a purpose of decrement
    # and send the absolute value of the amount.
    positive = amount && amount >= 0
    add_element(charge_field, "Value", amount&.abs)
    add_element(charge_field, "Currency", currency)
    add_element(charge_field, "Purpose", positive ? "Increment" : "Decrement")

    charge_field
  end

  def generate_date_time_elements parent_element, date, time, timezone: nil
    add_element(parent_element, "Date", date)
    add_element(parent_element, "Time", time)
    add_element(parent_element, "TimeZone", timezone) unless timezone.nil?
    parent_element
  end

  def find_shipments_by_entry_snapshot entry_snapshot
    find_shipments(mf(entry_snapshot, :ent_transport_mode_code),
      Entry.split_newline_values(mf(entry_snapshot, :ent_mbols).to_s),
      Entry.split_newline_values(entry_house_bills(entry_snapshot)))
  end

  def has_charges? invoice_snapshot, code_map
    json_child_entities(invoice_snapshot, "BrokerInvoiceLine").each do |line|
      return true if !code_map[mf(line, :bi_line_charge_code)].blank?
    end

    false
  end

  def has_duty_charges? invoice_snapshot
    has_charges?(invoice_snapshot, duty_level_codes)
  end

  def has_container_charges? invoice_snapshot
    extract_container_level_charges(invoice_snapshot).size > 0
  end

  def invoice_type_xref
    {"DUTY" => DUTY_SYNC, "CONTAINER" => CONTAINER_SYNC}
  end

  # This method will extract all charge codes associated with container billing and will skip
  # any charge code listed by the skip codes method
  def extract_container_level_charges invoice_snapshot
    codes_to_skip = skip_codes + duty_level_codes.keys

    charges = {}
    json_child_entities(invoice_snapshot, "BrokerInvoiceLine").each do |line|
      charge_code = mf(line, :bi_line_charge_code)
      next if codes_to_skip.include?(charge_code)

      amount = mf(line, :bi_line_charge_amount)
      next if amount.nil? || amount.zero?

      gtn_code = container_level_codes[charge_code]
      gtn_code = catchall_gtn_code() if gtn_code.blank?
      charges[gtn_code] ||= BigDecimal("0")
      charges[gtn_code] += amount
    end

    charges
  end

  def catchall_gtn_code
    "942"
  end

  def prorate_values proration_sums, total_proration_value, charge_code, charge_amount, existing_prorations
    total_amount = charge_amount.abs
    proration_left = total_amount.dup
    negative_charge = charge_amount < 0

    prorations = {}

    proration_sums.each_pair do |proration_key, value|
      prorated_amount = BigDecimal("0")

      # If the proration object has no value, then we don't calculate it into the proration valuation
      if value && value.nonzero?
        # Truncate the amount at 2 decimal places (essentially to prevent fractional pennies - we'll add them back in below)
        proration_percentage = (value / total_proration_value).round(5, BigDecimal::ROUND_DOWN)

        prorated_amount = (total_amount * proration_percentage).round(2, BigDecimal::ROUND_DOWN)
      end

      prorations[proration_key] = prorated_amount
      proration_left -= prorated_amount
    end

    # If all the proration amounts are zero, then bail, because the loop below will never end
    proration_check = prorations.values.uniq
    raise "Invalid proration encountered. No amounts could be prorated due to missing weights in all containers." if proration_check.length == 1 && proration_check[0] == 0

    # At this point, just equally distribute the proration amounts left one penny at a time
    while(proration_left > 0)
      prorations.each_pair do |proration_key, amount|
        # If the proration bucket is zero, it means the line had no value, so don't add leftovers back into it
        next if amount.zero? && total_amount.nonzero?

        prorations[proration_key] = (amount + BigDecimal("0.01"))
        proration_left -= BigDecimal("0.01")

        break if proration_left <= 0
      end
    end

    # Now make sure to flip the sign if we had a negative charge
    if negative_charge
      prorations.each_pair do |proration_key, amount|
        prorations[proration_key] = amount * -1
      end
    end

    # Now validate that we actually prorated correctly and the math above worked...
    total = prorations.values.sum
    if total != charge_amount
      raise "Invalid proration calculation for charge code #{charge_code}.  Should have been billed $#{charge_amount}, but was $#{total}."
    end

    prorations.each_pair do |proration_key, amount|
      existing_prorations[proration_key] ||= {}
      existing_prorations[proration_key][charge_code] ||= BigDecimal("0")
      existing_prorations[proration_key][charge_code] += amount
    end

    existing_prorations
  end

  def find_and_reverse_original_invoice_xml_lines entry_snapshot, invoice_snapshot, invoice_type
    # What we're looking for is an debit invoice that was issued prior to the given snapshot that has the original
    # amounts billed to the customer.  This is done like this because we're using actual entry data to calculate
    # billing. So, in the time between when the original invoice was issued and the reversal is issued, entry data
    # may have changed.  However, we want to reverse all the lines at the same rates they were originally issued.
    # The only way to accomplish that is to retrieve the original bill and then reverse the amounts from that.
    invoice_amount_to_find = mf(invoice_snapshot, :bi_invoice_total) * -1
    charge_codes = json_child_entities(invoice_snapshot, "BrokerInvoiceLine").map { |line| mf(line, :bi_line_charge_code) }.sort
    original_invoice = nil
    sort_broker_invoice_snapshots(json_child_entities(entry_snapshot, "BrokerInvoice")).each do |other_invoice|
      # The invoices are iterated over in chronological order, so if we hit the snapshot we started with, it means
      # that there is no matching invoice issued prior to the one we're working with that has the orignal billing
      # amount we're looking for and the same charge codes.
      break if record_id(other_invoice) == record_id(invoice_snapshot)

      if mf(other_invoice, :bi_invoice_total) == invoice_amount_to_find
        other_charge_codes = json_child_entities(other_invoice, "BrokerInvoiceLine").map { |line| mf(line, :bi_line_charge_code) }.sort

        if charge_codes == other_charge_codes

          # Make sure the other invoice also DOES NOT have a reversal sync record...if it does, it means its already been reversed and we shouldn't
          # consider it again.  There's an extreme corner case where someone bills, reverses, rebills, reverses, rebills this deals with.
          invoice = find_entity_object(other_invoice)
          next if invoice.nil?

          sync_record = invoice.sync_records.find { |sr| sr.trading_partner == reversal_invoice_type(invoice_type) }
          if sync_record.nil? || sync_record.sent_at.nil?
            original_invoice = invoice
          end

          break if original_invoice
        end
      end
    end

    # If the original invoice can't be found, just bill this one normally.  This should be a corner case where something
    # was only partially reversed or something like that.  If that's the case, we still need to issue the credit, so
    # we can just do that using that standard billing generation code.
    return nil if original_invoice.nil?

    # Since we have the original invoice, we can then find the xml that was sent for it through the sync record
    sync_record = original_invoice.sync_records.find { |sr| sr.trading_partner == invoice_type_xref[invoice_type] }

    original_file = sync_record&.ftp_session&.attachment
    return nil if original_file.nil?

    invoice_lines = nil
    original_file.download_to_tempfile do |temp|
      xml = REXML::Document.new(temp.read)
      invoice_lines = REXML::XPath.each(xml, "/GenericInvoiceMessage/GenericInvoices/GenericInvoice/InvoiceDetails/InvoiceLineItem").to_a
    end

    invoice_lines.each do |line|
      # We need to add a 'Decrement' purpose to the ChargeField...this indicates to GTN that we're removing a charge value...(rather than sending a negative amount)
      line.get_elements("ChargeField").each do |field|
        purpose = REXML::XPath.first(field, "Purpose")
        # Purpose might be missing for earlier versions of the file where we weren't sending it on every invoice's ChargeField.  If it is missing
        # we can assume the original intent was for an Increment purpose
        if purpose.nil?
          add_element(field, "Purpose", "Decrement")
        else
          purpose.text = purpose.text.to_s.strip.upcase == "INCREMENT" ? "Decrement" : "Increment"
        end
      end
    end

    return [original_invoice, invoice_lines]
  end

  def sort_broker_invoice_snapshots snapshots
    snapshots.sort do |s1, s2|
      val = mf(s1, :bi_invoice_date) <=> mf(s2, :bi_invoice_date)
      if val == 0
        if mf(s1, :bi_source_system).to_s.strip.upcase == "FENIX"
          # Fenix suffixes are all numeric, so make sure to sort them as such
          val = mf(s1, :bi_suffix).to_i <=> mf(s2, :bi_suffix).to_i
        else
          # US suffixes are alphabetic (A, B, C, etc..)
          val = mf(s1, :bi_suffix).to_s <=> mf(s2, :bi_suffix).to_s
        end

      end
      val
    end
  end

  def generate_delete_invoice broker_invoice, invoice_type
    sync_record = broker_invoice.sync_records.find { |sr| sr.trading_partner == invoice_type_xref[invoice_type] }

    original_file = sync_record&.ftp_session&.attachment
    return nil if original_file.nil?

    xml = nil
    original_file.download_to_tempfile do |temp|
      xml = REXML::Document.new(temp.read)
    end

    return nil if xml.nil?

    purpose = REXML::XPath.first(xml, "/GenericInvoiceMessage/GenericInvoices/GenericInvoice/Purpose")
    return nil if purpose.nil?
    purpose.text = "Delete"

    xml
  end

  def reversal_invoice_type invoice_type
    invoice_type_xref[invoice_type] + " REVERSAL"
  end

  def credit_invoice? invoice_snapshot
    mf(invoice_snapshot, :bi_invoice_total).to_f < 0
  end

  # This method exists solely to strip BILLINGTEST out of the container number field when testing.
  # This can get removed once we're 100% live and sending invoices to PVH for all files.
  def entry_container_numbers entry_snapshot
    container_numbers = mf(entry_snapshot, :ent_container_nums)
    container_numbers.to_s.gsub(/\s*BILLINGTEST/, "")
  end

  # This method exists solely to strip BILLINGTEST out of the container number field when testing.
  # This can get removed once we're 100% live and sending invoices to PVH for all files.
  def entry_house_bills entry_snapshot
    house_bills = mf(entry_snapshot, :ent_hbols)
    house_bills.to_s.gsub(/\s*BILLINGTEST/, "")
  end

end; end; end; end
