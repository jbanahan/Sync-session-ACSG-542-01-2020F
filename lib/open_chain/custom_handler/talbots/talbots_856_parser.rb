require 'open_chain/edi_parser_support'
require 'open_chain/integration_client_parser'
require 'open_chain/custom_handler/vfitrack_custom_definition_support'

module OpenChain; module CustomHandler; module Talbots; class Talbots856Parser
  include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport
  include OpenChain::EdiParserSupport
  include OpenChain::IntegrationClientParser

  def self.integration_folder
    ["www-vfitrack-net/_talbots_856", "/home/ubuntu/ftproot/chainroot/www-vfitrack-net/_talbots_856"]
  end

  # NOTE: The self.parse method definition is defined in EdiParserSupport

  def business_logic_errors
    @business_logic_errors ||= Hash.new { |h, k| h[k] = [] }
  end

  def process_transaction user, transaction, last_file_bucket:, last_file_path:
    edi_segments = transaction.segments
    bsn_segment = find_segment(edi_segments, "BSN")
    raise EdiStructuralError, "No BSN segment found in 856." unless bsn_segment

    master_bill = find_ref_value(edi_segments, "BM")
    raise EdiStructuralError, "No REF segment found with a 'BM' qualifier.  A master bill must be sent with all 856 transactions." if master_bill.blank?

    date_time = "#{value(bsn_segment, 3)}-#{value(bsn_segment, 4)}"

    last_exported_from_source = parse_dtm_date_value date_time
    raise EdiStructuralError, "Invalid BSN03 / BSN04 Date/Time formatting for value #{date_time}." unless last_exported_from_source

    find_and_process_shipment(importer, master_bill, last_exported_from_source, last_file_bucket, last_file_path) do |shipment|
      if value(bsn_segment, 1) == "03"
        shipment.canceled_date = last_exported_from_source
        shipment.canceled_by = user
      else
        process_shipment(shipment, edi_segments)
      end
      raise_business_logic_errors if business_logic_errors.keys.present?
      shipment.save!
      shipment.create_snapshot user, nil, last_file_path
    end
  end

  def raise_business_logic_errors
    message = "".html_safe
    if business_logic_errors[:missing_orders].present?
      message << "<br>Talbots orders are missing for the following Order Numbers:<br>".html_safe
      message << business_logic_errors[:missing_orders].map { |o| CGI.escapeHTML o }.join('<br>').html_safe
    end
    if business_logic_errors[:missing_lines].present?
      message << "<br>Talbots order lines are missing for the following Order Number / Sku pairs:<br>".html_safe
      message << business_logic_errors[:missing_lines].map { |ol| CGI.escapeHTML ol }.join('<br>').html_safe
    end
    raise EdiBusinessLogicError, message
  end

  def process_shipment(shipment, segments)
    shipment_loop = extract_hl_loops(segments, stop_segments: "CTT")
    process_shipment_header(shipment, shipment_loop[:segments])

    shipment_loop[:hl_children].each do |equipment_loop|
      # This is the Equipment (.ie container) loop
      container = process_container(shipment, equipment_loop[:segments])

      equipment_loop[:hl_children].each do |order_loop|
        order = process_order(shipment, order_loop[:segments])

        if order
          order_loop[:hl_children].each { |item_loop| process_item(shipment, container, order, item_loop[:segments]) }
        end
      end
    end

    # As soon as we get an 856, we'll want to generate the CI load / Entry data for it...we also want to sent out a CI Load
    # for every single update to the shipment (since an 856 is sent for each container, there'll be muliple docs generated)
    shipment.find_and_set_custom_value(cdefs[:shp_invoice_prepared_date], Time.zone.now)
    shipment.find_and_set_custom_value(cdefs[:shp_entry_prepared_date], Time.zone.now)

    shipment
  end

  def process_shipment_header shipment, header_segments
    find_segment(header_segments, "V1") do |v1|
      shipment.vessel = value(v1, 2)
      shipment.voyage = value(v1, 4)
      shipment.vessel_carrier_scac = value(v1, 5)

      mode = value(v1, 9)
      case mode.to_s.upcase
      when "A"
        shipment.mode = "Air"
      when "S"
        shipment.mode = "Ocean"
      end
    end

    find_segments(header_segments, "R4") do |r4|
      port_type = value(r4, 1).to_s.upcase
      port_code = value(r4, 3)
      next if port_code.blank?

      port = Port.where(unlocode: port_code).first
      next if port.nil?

      case port_type
      when "L"
        shipment.lading_port = port
      when "D"
        shipment.entry_port = port
      when "M"
        shipment.inland_destination_port = port
      end
    end

    find_segments(header_segments, "DTM") do |dtm|
      dv = value(dtm, 2)
      id = value(dtm, 1)

      next if dv.blank? || id.blank?

      date = parse_dtm_date_value(dv).try(:to_date)
      next if date.nil?

      case id
      when "370"
        shipment.departure_date = date
      when "371"
        shipment.est_arrival_port_date = date
      when "017"
        shipment.est_inland_port_date = date
      end
    end
  end

  def process_container shipment, container_segments
    td3 = find_segment(container_segments, "TD3")
    raise EdiStructuralError, "All 856 documents should contain a TD3 segment." if td3.nil?

    container_number = "#{value(td3, 2)}#{value(td3, 3)}"

    container = shipment.containers.find {|c| c.container_number == container_number}
    if container.nil?
      container = shipment.containers.build container_number: container_number
    else
      # We should destroy all shipment lines that are referenced by this container since we'll rebuild
      # them from this document
      shipment.shipment_lines.each do |line|
        line.mark_for_destruction if line.container == container
      end
    end

    container.seal_number = value(td3, 9)
    container.size_description = value(td3, 10)

    container
  end

  def process_order shipment, order_segments
    prf = find_segment(order_segments, "PRF")
    order_number = value(prf, 1)
    raise EdiStructuralError, "All order HL loops must have a PRF01 value containing the Order #." if order_number.blank?

    find_order(order_number)
  end

  def process_item shipment, container, order, item_segments
    # As far as I know, only the SKU is used for Talbots to link back to an order line
    lin = find_segment(item_segments, "LIN")
    raise EdiStructuralError, "All Item HL Loops must contain an LIN segment." if lin.nil?

    # Yusen / Talbots send the style in the SKU..WTF...which matches back to the VA qualified value on the 850 (after stripping the season from it)
    style = find_segment_qualified_value(lin, "SK")
    raise EdiStructuralError, "All LIN segments must contain a 'SK' qualified value referencing the Item's Sku." if style.blank?

    order_line = order.order_lines.find { |line| line.product.try(:custom_value, cdefs[:prod_part_number]) == style }

    unless order_line
      business_logic_errors[:missing_lines] << "#{order.customer_order_number} / #{style}"
      return
    end

    line = shipment.shipment_lines.build
    line.container = container
    line.linked_order_line_id = order_line.id
    line.product = order_line.product

    coo = find_segment_qualified_value(lin, "ZZ")
    line.find_and_set_custom_value(cdefs[:shpln_coo], coo) unless coo.blank?

    find_segment(item_segments, "SN1") do |sn1|
      line.quantity = BigDecimal(value(sn1, 2).to_s)
    end

    find_segment(item_segments, "TD1") do |td1|
      line.carton_qty = BigDecimal(value(td1, 2).to_s)
      line.gross_kgs = BigDecimal(value(td1, 7).to_s)
      line.cbms = BigDecimal(value(td1, 9).to_s)
    end

    line
  end


  def find_and_process_shipment importer, master_bill, last_exported_from_source, last_file_bucket, last_file_path
    shipment = nil
    reference = "#{importer.system_code}-#{master_bill}"
    Lock.acquire("Shipment-#{reference}") do
      s = Shipment.where(importer_id: importer.id, reference: reference).first_or_create! last_exported_from_source: last_exported_from_source

      if process_file?(s, last_exported_from_source)
        shipment = s
      end
    end
    Lock.with_lock_retry(shipment) do
      return nil unless process_file?(shipment, last_exported_from_source)

      shipment.master_bill_of_lading = master_bill
      shipment.last_file_bucket = last_file_bucket
      shipment.last_file_path = last_file_path

      yield shipment

    end if shipment
  end

  def process_file? shipment, last_exported_from_source
    shipment.last_exported_from_source.nil? || shipment.last_exported_from_source <= last_exported_from_source
  end

  def importer
    @imp ||= Company.where(importer: true, system_code: "TALBO").first
    raise "No importer found with system code TALBO." unless @imp
    @imp
  end

  def find_order order_number
    @cache = Hash.new do |h, k|
      order = Order.where(importer_id: importer.id, customer_order_number: order_number).first
      unless order
        business_logic_errors[:missing_orders] << order_number
        return
      end
      h[k] = order
    end

    @cache[order_number]
  end

  def cdefs
    @cdefs ||= self.class.prep_custom_definitions([:shpln_coo, :shp_entry_prepared_date, :shp_invoice_prepared_date, :prod_part_number])

    @cdefs
  end

end; end; end; end
