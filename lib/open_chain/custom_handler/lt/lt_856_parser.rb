require 'open_chain/edi_parser_support'
require 'open_chain/integration_client_parser'
require 'open_chain/custom_handler/vfitrack_custom_definition_support'

module OpenChain; module CustomHandler; module Lt; class Lt856Parser
  include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport
  include OpenChain::EdiParserSupport
  include OpenChain::IntegrationClientParser

  def importer
    @imp ||= Company.where(importer: true, system_code: "LOLLYT").first
    raise "No importer found with System Code LOLLYT." unless @imp
    @imp
  end

  def cdefs
    @cdefs ||= self.class.prep_custom_definitions([:shp_entry_prepared_date])
  end

  def business_logic_errors
    @business_logic_errors ||= Hash.new { |h, k| h[k] = Set.new }
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
    imp_reference = find_ref_value(edi_segments, "ZZ")
    mbol = find_ref_value(edi_segments, "BM")
    mode = value(bsn_segment, 5) == "0003" ? "Ocean" : "Air"
    last_exported_from_source = parse_dtm_date_value date_time
    raise EdiStructuralError, "Invalid BSN03 / BSN04 Date/Time formatting for value #{date_time}." unless last_exported_from_source

    find_and_process_shipment(importer, imp_reference, mode, mbol, last_exported_from_source, last_file_bucket, last_file_path) do |shipment|
      process_shipment(shipment, edi_segments)
      raise_business_logic_errors if business_logic_errors.keys.present?
      shipment.save!
      shipment.create_snapshot user, nil, last_file_path
    end
  end

  def raise_business_logic_errors
    message = "".html_safe
    if business_logic_errors[:missing_orders].present?
      message << "<br>LT orders are missing for the following Order Numbers:<br>".html_safe
      message << business_logic_errors[:missing_orders].map { |o| CGI.escapeHTML o }.join('<br>').html_safe
    end
    if business_logic_errors[:missing_lines].present?
      message << "<br>LT order lines are missing for the following Order / UPC pairs:<br>".html_safe
      message << business_logic_errors[:missing_lines].map { |ol| CGI.escapeHTML ol }.join('<br>').html_safe
    end
    if business_logic_errors[:missing_container].present?
      shipment_number = CGI.escapeHTML(business_logic_errors[:missing_container].first)
      message << "<br>LT containers are missing for the following ocean Shipment: #{shipment_number}".html_safe
    end
    raise EdiBusinessLogicError, message
  end

  def find_and_process_shipment importer, imp_reference, mode, mbol, last_exported_from_source, last_file_bucket, last_file_path
    shipment = nil
    reference = "#{importer.system_code}-#{imp_reference}"
    Lock.acquire("Shipment-#{reference}") do
      s = Shipment.where(importer_id: importer.id, reference: reference).first_or_create!
      shipment = s if process_file?(s, last_exported_from_source)
    end
    if shipment
      Lock.with_lock_retry(shipment) do
        shipment.assign_attributes(importer_reference: imp_reference, last_exported_from_source: last_exported_from_source, mode: mode,
                                   master_bill_of_lading: mbol, last_file_bucket: last_file_bucket, last_file_path: last_file_path)
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
    if shipment.mode == "Ocean"
      process_equipment_loop(shipment_loop[:hl_children], shipment)
    else
      process_order_loop(shipment_loop[:hl_children], shipment)
    end

    # As soon as we get an 856, we'll want to generate the CI load for it...
    shipment.find_and_set_custom_value(cdefs[:shp_entry_prepared_date], Time.zone.now)
  end

  def process_equipment_loop hl_children, shipment
    hl_children.each do |equipment_loop|
      if find_segment(equipment_loop[:segments], "TD3").present?
        container = process_container(shipment, equipment_loop[:segments])
        process_order_loop(equipment_loop[:hl_children], shipment, container)
      else
        business_logic_errors[:missing_container] << shipment.reference
      end
    end
  end

  def process_order_loop hl_children, shipment, container=nil
    hl_children.each do |order_loop|
      order = process_order(shipment, order_loop[:segments])

      if order
        order_loop[:hl_children].each { |item_loop| process_item(shipment, container, order, item_loop[:segments]) }
      end
    end
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
      when "371"
        shipment.est_arrival_port_date = date
      end
    end
  end

  def process_header_v1 shipment, header_segments
    find_segments(header_segments, "V1") do |v1|
      vessel = value(v1, 2)
      vessel_carrier_scac = value(v1, 5)
      shipment.vessel = vessel if vessel
      shipment.vessel_carrier_scac = vessel_carrier_scac if vessel_carrier_scac
      shipment.voyage = value(v1, 4)
      shipment.country_origin = Country.where(iso_code: value(v1, 3)).first
    end
  end

  def port_code_type_lookup
    {"O-OR" => :schedule_k_code,
     "D-PB" => :schedule_d_code,
     "N-PD" => :schedule_d_code,
     "L-KL" => :schedule_k_code,
     "H-ZZ" => :schedule_k_code}
  end

  def get_port_code_type r4, header_segments
    qualifier = [value(r4, 1).to_s.upcase, value(r4, 2).to_s.upcase].join("-")
    [qualifier, port_code_type_lookup[qualifier]]
  end

  def process_header_r4 shipment, header_segments
    find_segments(header_segments, "R4") do |r4|
      qualifier, port_code_type = get_port_code_type(r4, header_segments)
      port_code = value(r4, 3)
      next if port_code.blank?

      port = Port.where({port_code_type => port_code}).first
      next if port.nil?

      case qualifier
      when "O-OR"
        shipment.first_port_receipt = port
      when "D-PB"
        shipment.unlading_port = port
      when "N-PD"
        shipment.final_dest_port = port
      when "L-KL"
        shipment.lading_port = port
      when "H-ZZ"
        shipment.last_foreign_port = port
      end
    end
  end

  def process_container shipment, container_segments
    td3 = find_segment(container_segments, "TD3")
    shipment.containers.build(container_number: "#{value(td3, 2)}#{value(td3, 3)}", container_size: value(td3, 1), seal_number: value(td3, 9))
  end

  def process_order shipment, order_segments
    prf = find_segment(order_segments, "PRF")
    order_number = value(prf, 1)
    raise EdiStructuralError, "All order HL loops must have a PRF01 value containing the Order #." if order_number.blank?
    find_order(order_number)
  end

  def find_order order_number
    @order_cache ||= Hash.new do |h, k|
      order = Order.where(importer_id: importer.id, customer_order_number: k).first
      unless order
        business_logic_errors[:missing_orders] << k
      end
      h[k] = order
    end
    @order_cache[order_number]
  end

  def process_item shipment, container, order, item_segments
    lin = find_segment(item_segments, "LIN")
    raise EdiStructuralError, "All Item HL Loops must contain an LIN segment." if lin.nil?

    po4 = find_segment(item_segments, "PO4")
    upc = find_value_by_qualifier item_segments, "LIN06", "UP"
    net_weight = find_segments_by_qualifier(item_segments, "MEA02", "N")&.first
    if upc
      order_line = order.order_lines.find { |line| line.sku == upc }
    end
    unless order_line
      business_logic_errors[:missing_lines] << "#{order.customer_order_number} / #{upc}"
      return
    end
    line = shipment.shipment_lines.build(container: container, linked_order_line_id: order_line.id, product: order_line.product,
                                         carton_qty: value(po4, 1), cbms: value(po4, 8), gross_kgs: value(po4, 6), invoice_number: value(lin, 5))
    if net_weight.present?
      line.net_weight = BigDecimal(value(net_weight, 3))
      line.net_weight_uom = value(net_weight, 4)
    end
    process_item_sln line, item_segments
  end

  def process_item_sln line, item_segments
    find_segments(item_segments, "SLN") { |sln| line.quantity = value(sln, 4) }
  end

end; end; end; end
