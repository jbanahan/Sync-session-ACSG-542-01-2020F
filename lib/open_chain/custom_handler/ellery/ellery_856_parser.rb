require 'open_chain/edi_parser_support'
require 'open_chain/integration_client_parser'
require 'open_chain/custom_handler/vfitrack_custom_definition_support'

module OpenChain; module CustomHandler; module Ellery; class Ellery856Parser
  include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport
  include OpenChain::EdiParserSupport
  extend OpenChain::IntegrationClientParser

  def self.integration_folder
    ["www-vfitrack-net/ellery_856", "/home/ubuntu/ftproot/chainroot/www-vfitrack-net/ellery_856"]
  end

  def importer
    @imp ||= Company.where(importer: true, system_code: "ELLHOL").first
    raise "No importer found with System Code ELLHOL." unless @imp
    @imp
  end

  def cdefs
    @cdefs ||= self.class.prep_custom_definitions([:shpln_coo, :shpln_invoice_number, :shpln_received_date, :shp_invoice_prepared_date, :prod_part_number, :shp_entry_prepared_date])
  end

  def business_logic_errors
    @business_logic_errors ||= Hash.new { |h,k| h[k] = [] }
  end
  
  def port port_code
    Port.where(unlocode: port_code).first
  end

  def parse_date date_val
    Time.zone.parse(date_val) rescue nil
  end

  # NOTE: The self.parse method definition is defined in EdiParserSupport

  def process_transaction user, transaction, last_file_bucket:, last_file_path:
    edi_segments = transaction.segments
    bsn_segment = find_segment(edi_segments, "BSN")
    raise EdiStructuralError, "No BSN segment found in 856." unless bsn_segment

    date_time = "#{value(bsn_segment, 3)}-#{value(bsn_segment, 4)}"
    imp_reference = value(bsn_segment, 2)

    last_exported_from_source = parse_dtm_date_value date_time
    raise EdiStructuralError, "Invalid BSN03 / BSN04 Date/Time formatting for value #{date_time}." unless last_exported_from_source

    find_and_process_shipment(importer, imp_reference, last_exported_from_source, last_file_bucket, last_file_path) do |shipment|      
      process_shipment(shipment, edi_segments)
      raise_business_logic_errors if business_logic_errors.keys.present?
      shipment.save!
      shipment.create_snapshot user, nil, last_file_path
    end
  end

  def raise_business_logic_errors
    message = "".html_safe
    if business_logic_errors[:missing_orders].present?
      message << "<br>Ellery orders are missing for the following Order Numbers:<br>".html_safe
      message << business_logic_errors[:missing_orders].map{ |o| CGI.escapeHTML o }.join('<br>').html_safe
    end
    if business_logic_errors[:missing_lines].present?
      message << "<br>Ellery order lines are missing for the following Order / Part Number pairs:<br>".html_safe
      message << business_logic_errors[:missing_lines].map{ |ol| CGI.escapeHTML ol }.join('<br>').html_safe
    end
    raise EdiBusinessLogicError, message
  end

  def find_and_process_shipment importer, imp_reference, last_exported_from_source, last_file_bucket, last_file_path
    shipment = nil
    reference = "#{importer.system_code}-#{imp_reference}"
    Lock.acquire("Shipment-#{reference}") do
      s = Shipment.where(importer_id: importer.id, reference: reference).first_or_create!
      shipment = s if process_file?(s, last_exported_from_source)
    end
    if shipment
      Lock.with_lock_retry(shipment) do 
        shipment.assign_attributes(importer_reference: imp_reference, last_exported_from_source: last_exported_from_source, 
                                   last_file_bucket: last_file_bucket, last_file_path: last_file_path, gross_weight: 0, volume: 0)
        yield shipment 
      end
    end
  end

  def process_file? shipment, last_exported_from_source
    shipment.last_exported_from_source.nil? || shipment.last_exported_from_source <= last_exported_from_source
  end

  def process_shipment(shipment, segments)
    shipment_loop = extract_hl_loops(segments)
    process_shipment_header(shipment, shipment_loop[:segments])

    shipment.containers.each(&:mark_for_destruction)
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

    # As soon as we get an 856, we'll want to generate the CI load for it...
    shipment.find_and_set_custom_value(cdefs[:shp_invoice_prepared_date], Time.zone.now)
    shipment.find_and_set_custom_value(cdefs[:shp_entry_prepared_date], Time.zone.now)
  end

  def process_shipment_header shipment, header_segments
    process_header_dtm shipment, header_segments
    process_header_v1 shipment, header_segments
    process_header_r4 shipment, header_segments
  end

  def process_header_dtm shipment, header_segments
    find_segments(header_segments, "DTM") do |dtm|
      dv = value(dtm, 2)
      id = value(dtm, 1)

      next if dv.blank? || id.blank?
      date = parse_dtm_date_value(dv).try(:to_date)
      next if date.nil?

      case id
      when "369"
        shipment.est_departure_date = date
      when "370"
        shipment.departure_date = date
      when "371"
        shipment.est_arrival_port_date = date
      when "372"
        shipment.arrival_port_date = date
      end
    end
  end

  def process_header_v1 shipment, header_segments
    find_segments(header_segments, "V1") do |v1|
      vessel = value(v1, 2)
      shipment.vessel = vessel if vessel != "AIRFREIGHT"
      shipment.voyage = value(v1, 4)
      mode = value(v1, 9)
      case mode.to_s.upcase
      when "A"
        shipment.mode = "Air"
      when "O"
        shipment.mode = "Ocean"
      end
    end
  end

  def process_header_r4 shipment, header_segments
    find_segments(header_segments, "R4") do |r4|
      port_type = value(r4, 1).to_s.upcase
      port_code = value(r4, 3)
      next if port_code.blank?

      port = Port.where(unlocode: port_code).first
      next if port.nil?

      case port_type
      when "O"
        shipment.lading_port = port
      when "L"
        shipment.last_foreign_port = port
      when "D"
        shipment.destination_port = port
      when "N"
        shipment.unlading_port = port
      end
    end
  end

  def process_container shipment, container_segments
    ref = find_segment(container_segments, "REF")
    td1 = find_segment(container_segments, "TD1")
    td3 = find_segment(container_segments, "TD3")
    raise EdiStructuralError, "All 856 documents should contain a TD3 segment." if td3.nil?
    
    shipment.gross_weight += BigDecimal(value(td1, 7))
    shipment.volume += BigDecimal(value(td1, 9))
    shipment.shipment_type = value(ref, 2) if value(ref, 1) == "XY"

    shipment.containers.build(container_number: "#{value(td3, 2)}#{value(td3, 3)}", container_size: value(td3, 1), seal_number: value(td3, 9))
  end

  def process_order shipment, order_segments
    prf = find_segment(order_segments, "PRF")
    order_number = value(prf, 1)
    raise EdiStructuralError, "All order HL loops must have a PRF01 value containing the Order #." if order_number.blank?

    find_order(order_number)
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

  def process_item shipment, container, order, item_segments
    lin = find_segment(item_segments, "LIN")
    raise EdiStructuralError, "All Item HL Loops must contain an LIN segment." if lin.nil?

    part_num = value(lin, 3) if value(lin, 2) == "IN" 
    if part_num
      order_line = order.order_lines.find { |line| line.product.try(:custom_value, cdefs[:prod_part_number]) == part_num }
    end
    unless order_line
      business_logic_errors[:missing_lines] << "#{order.customer_order_number} / #{part_num}"
      return
    end

    line = shipment.shipment_lines.build(container: container, linked_order_line_id: order_line.id, product: order_line.product)
    coo = value(lin, 11) if value(lin, 10) == "CH"
    line.find_and_set_custom_value(cdefs[:shpln_coo], coo) unless coo.blank?

    process_item_sln line, item_segments
    process_item_ref shipment, line, item_segments
    process_item_dtm shipment, line, item_segments
  end

  def process_item_sln line, item_segments
    find_segments(item_segments, "SLN") do |sln|
      v = value(sln, 4)
      
      case value(sln, 1)
      when "Q1"
        line.quantity = v
      when "Q2"  
        line.carton_qty = v
      when "Q3"
        line.cbms = v
      when "Q4"
        line.gross_kgs = v
      end
    end
  end

  def process_item_ref shipment, line, item_segments
    find_segments(item_segments, "REF") do |ref|
      v = value(ref, 2)

      case value(ref, 1)
      when "4H"
        line.find_and_set_custom_value(cdefs[:shpln_invoice_number], v)
      when "MB"
        line.master_bill_of_lading = v
        shipment.vessel_carrier_scac = v[0..3] if shipment.mode = "Ocean"
        assign_header_master_bill shipment, v
      when "FN"
        line.fcr_number = v
      end
    end
  end

  def assign_header_master_bill shipment, mbol
    if shipment.master_bill_of_lading
      mbol_set = shipment.master_bill_of_lading.split("\n ").to_set
      shipment.master_bill_of_lading = mbol_set.add(mbol).to_a.join("\n ") 
    else
      shipment.master_bill_of_lading = mbol
    end
  end
  
  def process_item_dtm shipment, line, item_segments
    find_segments(item_segments, "DTM") do |dtm|
      v = value(dtm, 2)

      case value(dtm, 1)
      when "050"
        line.find_and_set_custom_value(cdefs[:shpln_received_date], v)
      when "537"
        shipment.docs_received_date = v
      end
    end
  end

end; end; end; end
