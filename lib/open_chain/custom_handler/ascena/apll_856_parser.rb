require 'open_chain/integration_client_parser'
require 'rex12'

module OpenChain; module CustomHandler; module Ascena; class Apll856Parser
  extend OpenChain::IntegrationClientParser
  IGNORE_SEGMENTS = ['ISA','GS','GE','IEA']

  def self.integration_folder
    "/home/ubuntu/ftproot/chainroot/www-vfitrack-net/_ascena_apll_asn"
  end

  def self.parse data, opts={}
    errors = []
    isa_code = 'UNKNOWN'
    begin
      cdefs = {}
      shipment_segments = []
      REX12::Document.parse(data) do |seg|
        isa_code = seg.elements[13].value if seg.segment_type=='ISA'
        next if IGNORE_SEGMENTS.include?(seg.segment_type)
        shipment_segments << seg
        if seg.segment_type=='SE'
          begin
            process_shipment(shipment_segments,cdefs, last_file_bucket: opts[:bucket], last_file_path: opts[:key])
          rescue
            errors << $!
          end
          shipment_segments = []
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
          to = "ascena_us@vandegriftinc.com,edisupport@vandegriftinc.com"
          subject = "Ascena/APLL ASN EDI Processing Error (ISA: #{isa_code})"
          OpenMailer.send_simple_html(to, subject, body.html_safe, [f]).deliver!
        end
      end
    end
  end

  def self.process_shipment shipment_segments, cdefs, last_file_path: nil, last_file_bucket: nil
    ActiveRecord::Base.transaction do
      hbol = find_ref_value(shipment_segments,'BM')
      booking_number = find_ref_value(shipment_segments,'CR')
      reference = "ASCENA-#{hbol}-#{booking_number}"
      Lock.acquire(reference) do
        raise "Cannot update existing shipment #{reference}" unless Shipment.where(reference: reference).empty?
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
          vessel:find_element_value(shipment_segments,'V1',2),
          voyage:find_element_value(shipment_segments,'V1',4),
          vessel_carrier_scac:find_element_value(shipment_segments,'V1',5),
          mode:find_mode(shipment_segments),
          lading_port:find_port(shipment_segments,'L'),
          unlading_port:find_port(shipment_segments,'D'),
          shipment_type:shipment_type,
          importer_id: importer.id,
          last_file_bucket: last_file_bucket,
          last_file_path: last_file_path
        )
        shp.save!

        equipments.each {|eq| process_equipment(shp,eq)}

        shp.create_snapshot User.integration, nil, "APLL 856 Parser"
      end
    end
  end

  def self.process_equipment shp, e_segs
    container_scac = find_element_value(e_segs,'TD3',2)
    container_num = find_element_value(e_segs,'TD3',3)
    con = shp.containers.build(
      container_number:"#{container_scac}#{container_num}",
      seal_number:find_element_value(e_segs,'TD3',9)
    )
    con.save!
    find_subloop(e_segs,'O').each {|o_segs| process_order(shp,con,o_segs)}
  end

  def self.process_order shp, con, o_segs
    ord_num = find_element_value(o_segs,'PRF',1)
    find_subloop(o_segs,'I').each {|i_segs| process_item(shp,con,ord_num,i_segs)}
  end

  def self.process_item shp, con, order_number, i_segs
    style = find_element_value(i_segs,'LIN',3)
    raise "Style number is required in LIN segment position 4." if style.blank?
    ol = OrderLine.joins(:order,:product).
      where("orders.order_number = ?","ASCENA-#{order_number}").
      where("products.unique_identifier = ?","ASCENA-#{style}").
      first
    raise "Order Line not found for order ASCENA-#{order_number}, style ASCENA-#{style}" if ol.nil?
    sl = shp.shipment_lines.build(
      product:ol.product,
      container: con,
      quantity:find_element_by_qualifier(i_segs, 'SLN', 'Q1', 1, 4),
      carton_qty:find_element_by_qualifier(i_segs, 'SLN', 'Q2', 1, 4),
      cbms:find_element_by_qualifier(i_segs, 'SLN', 'Q3', 1, 4),
      gross_kgs:find_element_by_qualifier(i_segs, 'SLN', 'Q4', 1, 4),
    )
    sl.linked_order_line_id = ol.id
    sl.save!
  end


  def self.find_subloop parent_segments, loop_type
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
    val = find_element_value(segments,'V1',9)
    return case val
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
    port_code = find_element_by_qualifier(segments,'R4',qualifier,1,3)
    port_code ? Port.find_by_unlocode(port_code) : nil
  end
  def self.find_ref_value segments, qualifier
    find_element_by_qualifier(segments,'REF',qualifier,1,2)
  end

  def self.get_date segments, qualifier
    dt = find_element_by_qualifier(segments,'DTM',qualifier,1,2)
    dt ? Date.new(dt[0..3].to_i,dt[4..5].to_i,dt[6..7].to_i) : nil
  end

  def self.find_element_value segments, type, element_position
    val = nil
    found = segments.find {|seg| seg.segment_type==type}
    if found
      el = found.elements[element_position]
      val = el ? el.value : nil
    end
    val
  end

  def self.find_element_by_qualifier segments, segment_type, qualifier, qualifier_position, value_position
    found = segments.find {|seg| seg.segment_type==segment_type && seg.elements[qualifier_position].value==qualifier}
    return found ? found.elements[value_position].value : nil
  end

  def self.importer
    @importer ||= Company.where(system_code: "ASCENA").first_or_create!(name:'ASCENA TRADE SERVICES LLC', importer:true)
  end
end; end; end; end
