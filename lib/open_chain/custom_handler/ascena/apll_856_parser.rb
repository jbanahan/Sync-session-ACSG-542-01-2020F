require 'rex12'
require 'open_chain/integration_client_parser'
require 'open_chain/edi_parser_support'

module OpenChain; module CustomHandler; module Ascena; class Apll856Parser
  extend OpenChain::IntegrationClientParser
  extend OpenChain::EdiParserSupport

  def self.integration_folder
    "/home/ubuntu/ftproot/chainroot/www-vfitrack-net/_ascena_apll_asn"
  end

  def self.parse data, opts={}
    errors = []
    isa_code = 'UNKNOWN'
    begin
      cdefs = {}
      shipment_segments = []
      REX12::Document.each_transaction(data) do |transaction|
        isa_code = transaction.isa_segment.elements[13].value
        begin
          process_shipment(transaction.segments,cdefs, last_file_bucket: opts[:bucket], last_file_path: opts[:path])
        rescue
          errors << $!
        end
      end
    rescue
      errors << $!
    ensure
      if !errors.empty?
        Tempfile.create(["APLLEDI-#{isa_code}",'.txt']) do |f|
          f << data
          f.flush
          body = "<p>There was a problem processing the attached APLL ASN EDI for Ascena Global. An IT ticket has been opened about the issue, and the EDI is attached.</p><p>Errors:<br><ul>"
          errors.each {|err| body << "<li>#{ERB::Util.html_escape(err.message)}</li>"}
          body << "</ul></p>"
          to = "edisupport@vandegriftinc.com"
          subject = "Ascena/APLL ASN EDI Processing Error (ISA: #{isa_code})"
          OpenMailer.send_simple_html(to, subject, body.html_safe, [f]).deliver!
        end
      end
    end
  end

  def self.process_shipment shipment_segments, cdefs, last_file_path: nil, last_file_bucket: nil
    shipment = nil
    ActiveRecord::Base.transaction do
      hbol = find_ref_value(shipment_segments,'BM')
      booking_number = find_ref_value(shipment_segments,'CR')
      reference = "ASCENA-#{hbol}-#{booking_number}"
      Lock.acquire(reference) do
        # We never update shipments...
        return unless Shipment.where(reference: reference).empty?
        est_arrival_port_date = get_date(shipment_segments,'056')
        est_arrival_port_date = get_date(shipment_segments,'AA2') unless est_arrival_port_date
        equipments = find_subloop(shipment_segments,'E')
        shipment_type = equipments.empty? ? nil : find_ref_value(equipments.first,'XY')
        shp = Shipment.new(
          reference:reference,
          house_bill_of_lading:hbol,
          booking_number:booking_number,
          est_departure_date:get_date(shipment_segments,'369'),
          departure_date:get_date(shipment_segments,'370'),
          est_arrival_port_date:est_arrival_port_date,
          vessel:find_element_value(shipment_segments,'V102'),
          voyage:find_element_value(shipment_segments,'V104'),
          vessel_carrier_scac:find_element_value(shipment_segments,'V105'),
          mode:find_mode(shipment_segments),
          lading_port:find_port(shipment_segments,'L'),
          unlading_port:find_port(shipment_segments,'D'),
          shipment_type:shipment_type,
          importer_id: importer.id,
          last_file_bucket: last_file_bucket,
          last_file_path: last_file_path
        )
        shp.save!

        errors = []
        equipments.each do |eq| 
          equip_errors = process_equipment(shp,eq)
          errors.push *equip_errors
        end

        shp.marks_and_numbers = errors.length > 0 ? "* #{errors.join("\n* ")}" : nil

        shp.create_snapshot User.integration, nil, "APLL 856 Parser"

        shipment = shp
      end
    end

    shipment
  end

  def self.process_equipment shp, e_segs
    container_scac = find_element_value(e_segs,'TD302')
    container_num = find_element_value(e_segs,'TD303')
    con = shp.containers.build(
      container_number:"#{container_scac}#{container_num}",
      seal_number:find_element_value(e_segs,'TD309')
    )
    con.save!
    errors = []
    find_subloop(e_segs,'O').each do |o_segs| 
      order_errors = process_order(shp,con,o_segs)
      errors.push *order_errors
    end

    errors
  end

  def self.process_order shp, con, o_segs
    ord_num = find_element_value(o_segs,'PRF01')
    errors = []
    find_subloop(o_segs,'I').each do |i_segs| 
      begin
        process_item(shp,con,ord_num,i_segs)
      rescue OrderMissingError => e
        errors << e.message
      end
    end

    errors
  end

  class OrderMissingError < StandardError

  end

  def self.process_item shp, con, order_number, i_segs
    style = find_element_value(i_segs,'LIN03')
    raise "Style number is required in LIN segment position 4." if style.blank?
    ol = OrderLine.joins(:order,:product).
      where("orders.order_number = ?","ASCENA-#{order_number}").
      where("products.unique_identifier = ?","ASCENA-#{style}").
      first
    raise OrderMissingError, "Order Line not found for order ASCENA-#{order_number}, style ASCENA-#{style}" if ol.nil?
    sl = shp.shipment_lines.build(
      product:ol.product,
      container: con,
      quantity:find_value_by_qualifier(i_segs, 'SLN01', 'Q1', value_index: 4),
      carton_qty:find_value_by_qualifier(i_segs, 'SLN01', 'Q2', value_index: 4),
      cbms:find_value_by_qualifier(i_segs, 'SLN01', 'Q3', value_index: 4),
      gross_kgs:find_value_by_qualifier(i_segs, 'SLN01', 'Q4', value_index: 4)
    )
    sl.linked_order_line_id = ol.id
    sl.save!
  end


  def self.find_subloop parent_segments, loop_type
    # This method is now outdated and left alone purely for time constraint purposes...
    
    # Don't utilize this sort of processing any longer...see the extract_hl_loops method in edi_parser_support
    # for a much superior means of handling HL loops in an 856

    # skip everything before the first HL(E) loop
    all_segments = []
    found_equipment_loop = false
    parent_segments.each do |seg|
      type = seg.segment_type
      next if type=='CTT' || type=='SE'
      found_equipment_loop = true if type=='HL' && seg.elements[3].value==loop_type
      all_segments << seg if found_equipment_loop
    end

    # split into separate sub-arrays for each HL(E) loop
    r = []
    current_match = []
    all_segments.each do |seg|
      type = seg.segment_type
      if type=='HL' && seg.elements[3].value==loop_type
        r << current_match unless current_match.empty?
        current_match = []
      end
      current_match << seg
    end
    r << current_match unless current_match.empty?
    r
  end

  def self.find_mode segments
    case find_element_values(segments,'V109').first
    when 'O'
      'Ocean'
    when 'A'
      'Air'
    when 'T'
      'Truck'
    else
      'Other'
    end
  end

  def self.find_port segments, qualifier
    port_code = find_value_by_qualifier(segments, "R401", qualifier, value_index: 3)
    port_code ? Port.find_by_unlocode(port_code) : nil
  end

  def self.get_date segments, qualifier
    dt = find_date_value(segments, qualifier)
    dt.nil? ? nil : dt.to_date
  end

  def self.importer
    @importer ||= Company.where(system_code: "ASCENA").first_or_create!(name:'ASCENA TRADE SERVICES LLC', importer:true)
  end
end; end; end; end
