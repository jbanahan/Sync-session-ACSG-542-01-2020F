require 'open_chain/xml_builder'
require 'open_chain/ftp_file_support'
require 'open_chain/entity_compare/comparator_helper'

module OpenChain; module CustomHandler; module Pvh; module PvhBillingFileGeneratorSupport
  extend ActiveSupport::Concern
  include OpenChain::XmlBuilder
  include OpenChain::FtpFileSupport
  include OpenChain::EntityCompare::ComparatorHelper

  # This is simply a sync record we're going to add to ANY broker invoice we've already generated billing data for
  # We'll then use the more specific sync codes to associate sync records with the actual files we're generating
  # for the Duty files, the brokerage charge files, and the bill of lading level charges.
  PRIMARY_SYNC ||= "PVH BILLING"
  DUTY_SYNC ||= "PVH BILLING DUTY"
  CONTAINER_SYNC ||= "PVH BILLING CONTAINER"
  LINE_SYNC ||= "PVH BILLING INVOICE LINE"

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
    if has_duty_charges?(invoice_snapshot)
      sent = false
      if credit_invoice?(invoice_snapshot)
        sent = generate_and_send_reversal(entry_snapshot, invoice_snapshot, invoice, "DUTY")
      end

      generate_and_send_duty_charges(entry_snapshot, invoice_snapshot, invoice) unless sent
    end

    if has_line_charges?(invoice_snapshot)
      sent = false
      if credit_invoice?(invoice_snapshot)
        sent = generate_and_send_reversal(entry_snapshot, invoice_snapshot, invoice, "LINE")
      end

      generate_and_send_line_charges(entry_snapshot, invoice_snapshot, invoice) unless sent
    end

    if has_container_charges?(invoice_snapshot)
      sent = false
      if credit_invoice?(invoice_snapshot)
        sent = generate_and_send_reversal(entry_snapshot, invoice_snapshot, invoice, "CONTAINER")
      end

      generate_and_send_container_charges(entry_snapshot, invoice_snapshot, invoice) unless sent
    end

    sync_record = find_or_build_sync_record(invoice, PRIMARY_SYNC)
    sync_record.sent_at = Time.zone.now
    sync_record.confirmed_at = Time.zone.now + 1.minute

    sync_record.save!
    nil
  end

  def generate_and_send_line_charges(entry_snapshot, invoice_snapshot, invoice)
    invoice_date = mf(invoice_snapshot, :bi_invoice_date)
    currency = mf(invoice_snapshot, :bi_currency)
    generate_and_send_invoice_xml(invoice, invoice_snapshot, "LINE") do |details|
      # Extract all the charges and amounts we need to bill on this brokerage invoice
      charges = extract_invoice_line_level_charges(invoice_snapshot)

      invoice_lines = json_child_entities(entry_snapshot, "CommercialInvoice", "CommercialInvoiceLine")

      prorations = {}
      # Generate the prorations for each amount
      charges.each_pair do |code, amount|
        prorate_charge_across_all_invoice_lines(invoice_lines, code, amount, prorations)
      end

      if charges.size > 0
        invoice_lines.each do |line_snapshot|
          line_prorations = prorations[record_id(line_snapshot)]
          invoice_line = add_invoice_line(details, entry_snapshot, line_snapshot)

          line_prorations.each_pair do |charge_code, charge_amount|  
            add_invoice_line_charge(invoice_line, invoice_date, charge_amount, charge_code, currency)
          end
        end
      end
    end
  end

  def generate_and_send_container_charges(entry_snapshot, invoice_snapshot, invoice)
    invoice_date = mf(invoice_snapshot, :bi_invoice_date)
    currency = mf(invoice_snapshot, :bi_currency)
    generate_and_send_invoice_xml(invoice, invoice_snapshot, "CONTAINER") do |details|
      # Extract all the charges and amounts we need to bill on this brokerage invoice
      charges = extract_container_level_charges(invoice_snapshot)

      containers = Entry.split_newline_values(entry_container_numbers(entry_snapshot))

      prorations = {}
      # Generate the prorations for each amount
      charges.each_pair do |code, amount|
        prorate_charge_across_all_containers(entry_snapshot, containers, code, amount, prorations)
      end

      if charges.size > 0
        line_counter = 1
        containers.each do |container_number|
          line_prorations = prorations[container_number]

          line_prorations.each_pair do |charge_code, charge_amount|
            added = add_container_line(details, entry_snapshot, container_number, invoice_date, charge_amount, charge_code, currency, line_counter)
            line_counter += 1 if added
          end
        end
      end
    end
  end

  def unsent_invoices entry, broker_invoice_snapshots
    invoices = []
    broker_invoice_snapshots.each do |bi|
      invoice_number = mf(bi, "bi_invoice_number")
      broker_invoice = entry.broker_invoices.find {|inv| inv.invoice_number == invoice_number}

      # It's possible the invoice won't be found because it may have been updated in the intervening time from Kewill
      next if broker_invoice.nil? || broker_invoice.sync_records.find {|s| s.trading_partner == PRIMARY_SYNC && !s.sent_at.nil? }.present?

      invoices << {snapshot: bi, invoice: broker_invoice}
    end

    invoices
  end

  def generate_and_send_reversal(entry_snapshot, invoice_snapshot, invoice, invoice_type)
    original_invoice, invoice_xml_lines = find_and_reverse_original_invoice_xml_lines(entry_snapshot, invoice_snapshot, invoice_type)
    return false if invoice_xml_lines.blank?
    
    generate_and_send_invoice_xml(invoice, invoice_snapshot, invoice_type) do |details|
      invoice_xml_lines.each do |line|
        details << line
      end
    end

    original_invoice.sync_records.create! trading_partner: reversal_invoice_type(invoice_type), sent_at: Time.zone.now, confirmed_at: (Time.zone.now + 1.minute)
    true
  end

  def add_invoice_line parent_element, entry_snapshot, line_snapshot
    container_number = mf(line_snapshot, :cil_con_container_number)
    order_number = mf(line_snapshot, :cil_po_number)
    part_number = mf(line_snapshot, :cil_part_number)
    units = mf(line_snapshot, :cil_units)
    unit_price = mf(line_snapshot, :ent_unit_price)

    shipment_line = find_shipment_line(entry_snapshot, container_number, order_number, part_number, unit_price, units)
    # TODO What to do if the entry line doesn't match to any shipment line since we need the shipment line to set the ItemNumber XML value
    order_line = shipment_line&.order_line
    order_line_number = order_line&.line_number

    # If container number was blank above, we still could find it using the shipment line
    container = shipment_line&.container
    container_number = container&.container_number if container_number.blank?
    
    generate_invoice_line_item(parent_element, "Manifest Line Item", order_line_number, master_bill:  bill_number(container, shipment_line),
      container_number: container_number, order_number: order_number, part_number: part_number)
  end

  def add_invoice_line_charge parent_element, invoice_date, amount, code, currency
    generate_charge_field parent_element, "Manifest Line Item", code, invoice_date, amount, currency
  end

  def add_container_line parent_element, entry_snapshot, container_number, invoice_date, amount, code, currency, line_counter
    return false unless amount && amount.nonzero?

    container = find_shipment_container(entry_snapshot, container_number)

    line_item = generate_invoice_line_item(parent_element, "Container", line_counter, master_bill: bill_number(container, nil), container_number: container_number)
    generate_charge_field(line_item, "Container", code, invoice_date, amount, currency)
    return true
  end

  def bill_number container, shipment_line
    # For Ocean FCL modes we need to send the Master Bill as the BLNumber
    # For Ocean LCL / Air modes we need to send the House Bill as the BLNumber
    bill_of_lading = nil
    if container&.shipment&.mode.to_s.strip =~ /Ocean/i
      fcl = container&.fcl_lcl.to_s.strip.upcase != "LCL"
      bill_of_lading = fcl ? container&.shipment&.master_bill_of_lading : container&.shipment&.house_bill_of_lading
    else
      bill_of_lading = shipment_line&.shipment&.house_bill_of_lading
    end

    bill_of_lading
  end

  def generate_and_send_invoice_xml broker_invoice, broker_invoice_snapshot, invoice_type, &block
    xml, filename = generate_invoice_xml(broker_invoice_snapshot, invoice_type, &block)
    return nil unless xml.present?

    send_invoice_xml(broker_invoice, invoice_type, filename, xml)
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

  def generate_invoice_xml broker_invoice_snapshot, invoice_type
    # setup/reset any data used for any previous invoice generations
    reset_data

    doc, root = build_xml_document("GenericInvoiceMessage")
    invoice_number = mf(broker_invoice_snapshot, :bi_invoice_number)
    invoice_date = mf(broker_invoice_snapshot, :bi_invoice_date)

    filename = "GI_VANDE_PVH_#{invoice_number}_#{invoice_type}_#{Time.zone.now.to_i}.xml"

    invoice_element, invoice_header, invoice_details = generate_invoice_file_header(root, broker_invoice_snapshot, "#{invoice_number}-#{invoice_type}", invoice_date, filename)

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
    generate_date_time_elements(add_element(charge_field, "ChargeDate"), invoice_date.strftime("%Y-%m-%d"), "12:00:00", timezone: ActiveSupport::TimeZone["America/New_York"].now.zone)
    
    add_element(charge_field, "Value", amount)
    add_element(charge_field, "Currency", currency)

    charge_field
  end

  def generate_date_time_elements parent_element, date, time, timezone: nil
    add_element(parent_element, "Date", date)
    add_element(parent_element, "Time", time)
    add_element(parent_element, "TimeZone", timezone) unless timezone.nil?
    parent_element
  end

  def find_shipment_line entry_snapshot, container_number, order_number, part_number, unit_price, units
    shipments = find_shipments(entry_snapshot)

    # Narrow down the shipment_lines to search over if we have a container number
    shipment_lines = []
    if !container_number.blank?
      shipments.each do |s|
        container = s.containers.find {|c| c.container_number = container_number }
        shipment_lines.push *container.shipment_lines
      end
    else
      shipments.each do |shipment|
        shipment_lines.push *shipment.shipment_lines
      end
    end

    translated_part_number = "PVH-#{part_number}"

    # Find all the shipment lines that might match this part / order number...there's potentially more than one
    order_matched_lines = shipment_lines.select do |line|
      # Skip any shipment lines we've already returned
      next if found_shipment_lines.include?(line)

      line.product&.unique_identifier == translated_part_number && line.order_line&.order&.customer_order_number == order_number
    end

    # If there's only one line on the shipment that matches, then just return it
    return order_matched_lines[0] if order_matched_lines.length == 1

    # At this point we need to try and use other factors to determine which shipment line to match to as there's multiple lines
    # that have the same part number / order number (which is possible if they're shipping multiple colors/sizes on different lines)

    # Try to use the unit cost to find an exact match first
    ppu_matched_lines = order_matched_lines.select do |line|
      line.order_line.price_per_unit == unit_price
    end

    # If there's only one line on the shipment that matches, then just return it
    return ppu_matched_lines[0] if ppu_matched_lines.length == 1

    # If nothing matched, go back to the full order line matched list see if we can find an exact match based just on quantity
    ppu_matched_lines = order_matched_lines if ppu_matched_lines.length == 0

    unit_matched_lines = ppu_matched_lines.select do |line|
      line.quantity == units
    end

    line = unit_matched_lines.first

    line = ppu_matched_lines.first if line.blank?
    line = order_matched_lines.first if line.blank?

    # we don't want to re-use the same shipment line, so keep track of which ones we've returned
    found_shipment_lines << line if line

    line
  end

  def found_shipment_lines 
    @found_lines ||= Set.new
  end

  def find_shipment_container entry_snapshot, container_number
    shipments = find_shipments(entry_snapshot)

    container = nil
    shipments.each do |shipment|
      container = shipment.containers.find {|c| c.container_number == container_number }
      break unless container.nil?
    end

    # TODO - What to do if the container isn't found
    container
  end

  def find_shipments entry_snapshot
    # Find all PVH shipments with the bill of lading numbers present on the shipment...since we'll need them all 
    # anyway to bill the entry.
    @shipments ||= begin
      master_bills = Entry.split_newline_values(mf(entry_snapshot, :ent_mbols).to_s)
      Shipment.where(importer_id: pvh_importer.id, master_bill_of_lading: master_bills).to_a
    end
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

  def has_line_charges? invoice_snapshot
    extract_invoice_line_level_charges(invoice_snapshot).size > 0
  end

  def pvh_importer
    @pvh ||= Company.where(system_code: "PVH").first
  end

  def invoice_type_xref
    {"DUTY" => DUTY_SYNC, "CONTAINER" => CONTAINER_SYNC, "LINE" => LINE_SYNC}
  end

  # This method will ONLY extract charge codes listed in the given cross refernce
  def extract_container_level_charges invoice_snapshot
    charges = {}
    json_child_entities(invoice_snapshot, "BrokerInvoiceLine").each do |line|
      charge_code = mf(line, :bi_line_charge_code)
      amount = mf(line, :bi_line_charge_amount)
      next if amount.nil? || amount.zero?

      gtn_code = container_level_codes[charge_code]
      if !gtn_code.blank?
        charges[gtn_code] ||= BigDecimal("0")
        charges[gtn_code] += amount
      end
    end

    charges
  end

  # This method differs from the other extract charges method in that it will return every
  # charge code mapped to a GTN code, EXCEPT for those codes blacklisted in the skip_codes parameter
  def extract_invoice_line_level_charges invoice_snapshot
    codes_to_skip = (duty_level_codes.keys + container_level_codes.keys + skip_codes)

    charges = {}
    json_child_entities(invoice_snapshot, "BrokerInvoiceLine").each do |line|
      charge_code = mf(line, :bi_line_charge_code)
      next if codes_to_skip.include?(charge_code)

      amount = mf(line, :bi_line_charge_amount)
      next if amount.nil? || amount.zero?

      gtn_code = line_level_codes[charge_code]
      gtn_code = catchall_gtn_code() if gtn_code.blank?

      charges[gtn_code] ||= BigDecimal("0")
      charges[gtn_code] += amount
    end

    charges
  end

  def catchall_gtn_code
    "942"
  end

  def prorate_charge_across_all_invoice_lines commercial_invoice_lines, charge_code, charge_amount, existing_prorations
    # PVH wants us to prorate the charge amounts based on the percentage of total commercial invoice value that the
    # charge line makes up.
    total_commercial_invoice_value = BigDecimal("0")
    commercial_invoice_lines.each do |line|
      value = mf(line, :cil_value)
      if value 
        total_commercial_invoice_value += value
      end
    end

    total_amount = charge_amount.abs
    proration_left = total_amount.dup
    negative_charge = charge_amount < 0

    prorations = {}

    commercial_invoice_lines.each do |line|
      value = mf(line, :cil_value)
      prorated_amount = BigDecimal("0")

      # If the line carries no commercial invoice value, then we don't calculate it into the proration valuation
      if value && value.nonzero?
        # Truncate the amount at 2 decimal places (essentially to prevent fractional pennies - we'll add them back in below)
        proration_percentage = (value / total_commercial_invoice_value).round(5, BigDecimal::ROUND_DOWN)

        prorated_amount = (total_amount * proration_percentage).round(2, BigDecimal::ROUND_DOWN)
      end

      prorations[record_id(line)] = prorated_amount
      proration_left -= prorated_amount
    end

    # At this point, just equally distribute the proration amounts left one penny at a time
    while(proration_left > 0)
      prorations.each_pair do |id, amount|
        # If the proration bucket is zero, it means the line had no value, so don't add leftovers back into it
        next if amount.zero? && total_amount.nonzero?

        prorations[id] = (amount + BigDecimal("0.01"))
        proration_left -= BigDecimal("0.01")

        break if proration_left <= 0
      end
    end

    # Now make sure to flip the sign if we had a negative charge
    if negative_charge
      prorations.each_pair do |id, amount|
        prorations[id] = amount * -1
      end
    end

    # Now validate that we actually prorated correctly and the math above worked...
    total = prorations.values.sum
    if total != charge_amount
      raise "Invalid proration calculation for charge code #{charge_code}.  Should have been billed $#{charge_amount}, but was $#{total}."
    end

    commercial_invoice_lines.each do |line|
      id = record_id(line)
      existing_prorations[id] ||= {}
      existing_prorations[id][charge_code] ||= BigDecimal("0")
      existing_prorations[id][charge_code] += prorations[id]
    end

    existing_prorations
  end

  def prorate_charge_across_all_containers entry_snapshot, container_numbers, charge_code, charge_amount, existing_prorations
    total_container_weight = BigDecimal("0")
    container_weights = {}

    container_numbers.each do |container_number|
      container = find_shipment_container(entry_snapshot, container_number)

      container_weight = container.shipment_lines.map {|line| line.gross_kgs }.compact.sum
      container_weights[container_number] = container_weight

      total_container_weight += container_weight if container_weight && container_weight.nonzero?
    end

    total_amount = charge_amount.abs
    proration_left = total_amount.dup
    negative_charge = charge_amount < 0

    prorations = {}

    container_weights.each_pair do |container_number, weight|
      prorated_amount = BigDecimal("0")

      # If the container has no weight, then we don't calculate it into the proration valuation
      if weight && weight.nonzero?
        # Truncate the amount at 2 decimal places (essentially to prevent fractional pennies - we'll add them back in below)
        proration_percentage = (weight / total_container_weight).round(5, BigDecimal::ROUND_DOWN)

        prorated_amount = (total_amount * proration_percentage).round(2, BigDecimal::ROUND_DOWN)
      end

      prorations[container_number] = prorated_amount
      proration_left -= prorated_amount
    end

    # At this point, just equally distribute the proration amounts left one penny at a time
    while(proration_left > 0)
      prorations.each_pair do |container_number, amount|
        # If the proration bucket is zero, it means the line had no value, so don't add leftovers back into it
        next if amount.zero? && total_amount.nonzero?

        prorations[container_number] = (amount + BigDecimal("0.01"))
        proration_left -= BigDecimal("0.01")

        break if proration_left <= 0
      end
    end

    # Now make sure to flip the sign if we had a negative charge
    if negative_charge
      prorations.each_pair do |container_number, amount|
        prorations[container_number] = amount * -1
      end
    end

    # Now validate that we actually prorated correctly and the math above worked...
    total = prorations.values.sum
    if total != charge_amount
      raise "Invalid proration calculation for charge code #{charge_code}.  Should have been billed $#{charge_amount}, but was $#{total}."
    end

    prorations.each_pair do |container_number, amount|
      existing_prorations[container_number] ||= {}
      existing_prorations[container_number][charge_code] ||= BigDecimal("0")
      existing_prorations[container_number][charge_code] += amount
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
    json_child_entities(entry_snapshot, "BrokerInvoice") do |other_invoice|
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
      invoice_lines = REXML::XPath.each(xml, "/GenericInvoiceMessage/GenericInvoices/GenericInvoice/InvoiceHeader/InvoiceDetails/InvoiceLineItem").to_a
    end

    invoice_lines.each do |line|
      # We need to add a 'Decrement' purpose to the ChargeField...this indicates to GTN that we're removing a charge value...(rather than sending a negative amount)
      line.get_elements("ChargeField").each do |field|
        add_element(field, "Purpose", "Decrement")
      end
    end

    return [original_invoice, invoice_lines]
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

end; end; end; end