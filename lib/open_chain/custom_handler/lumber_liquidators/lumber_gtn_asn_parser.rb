require 'rexml/document'
require 'open_chain/integration_client_parser'
require 'open_chain/custom_handler/xml_helper'
require 'open_chain/custom_handler/lumber_liquidators/lumber_custom_definition_support'

module OpenChain; module CustomHandler; module LumberLiquidators; class LumberGtnAsnParser
  include OpenChain::CustomHandler::XmlHelper
  include OpenChain::CustomHandler::LumberLiquidators::LumberCustomDefinitionSupport
  include OpenChain::IntegrationClientParser

  DATE_CODE_EMPTY_OUT_GATE_AT_ORIGIN = '25992'
  DATE_CODE_EST_ARRIVAL_DISCHARGE = '316'
  DATE_CODE_EST_DEPARTURE = '315'
  DATE_CODE_FULL_INGATE_AT_ORIGIN = '25991'
  DATE_CODE_EMPTY_RETURN = '24'
  DATE_CODE_DELIVERED = '21'
  DATE_CODE_CONTAINER_UNLOADED = '22'
  DATE_CODE_CARRIER_RELEASED = '11'
  DATE_CODE_CUSTOMS_RELEASED_CARRIER = '12'
  DATE_CODE_AVAILABLE_FOR_DELIVERY = '26002'
  DATE_CODE_FULL_INGATE = '25961'
  DATE_CODE_FULL_OUTGATE_DISCHARGE_PORT = '16'
  DATE_CODE_ON_RAIL_DESTINATION = '17'
  DATE_CODE_RAIL_ARRIVED_DESTINATION = '25966'
  DATE_CODE_ARRIVED = '9'
  DATE_CODE_DEPARTED = '6'
  DATE_CODE_DISCHARGED = '10'
  DATE_CODE_LOADED_AT_PORT = '5'
  DATE_CODE_ARRIVE_AT_TRANSSHIP_PORT = '403'
  DATE_CODE_DEPART_FROM_TRANSSHIP_PORT = '404'
  DATE_CODE_BARGE_DEPART = '27738'
  DATE_CODE_BARGE_ARRIVE = '27739'
  DATE_CODE_FCR_CREATED = '25981'

  # Allport's test system has different codes for some events.
  TEST_DATE_CODE_EMPTY_OUT_GATE_AT_ORIGIN = '38804'
  TEST_DATE_CODE_FULL_INGATE_AT_ORIGIN = '38803'
  TEST_DATE_CODE_CONTAINER_UNLOADED = '38780'
  TEST_DATE_CODE_AVAILABLE_FOR_DELIVERY = '38814'
  TEST_DATE_CODE_FULL_INGATE = '38773'
  TEST_DATE_CODE_RAIL_ARRIVED_DESTINATION = '38778'
  TEST_DATE_CODE_BARGE_DEPART = '40995'
  TEST_DATE_CODE_BARGE_ARRIVE = '40996'
  TEST_DATE_CODE_FCR_CREATED = '38793'

  # Codes that are the same for prod and test systems.
  COMMON_DATE_CDEF_MAP_ORDER = {
    DATE_CODE_EST_ARRIVAL_DISCHARGE=>:ord_asn_est_arrival_discharge,
    DATE_CODE_EST_DEPARTURE=>:ord_asn_est_departure,
    DATE_CODE_EMPTY_RETURN=>:ord_asn_empty_return,
    DATE_CODE_DELIVERED=>:ord_asn_delivered,
    DATE_CODE_CARRIER_RELEASED=>:ord_asn_carrier_released,
    DATE_CODE_CUSTOMS_RELEASED_CARRIER=>:ord_asn_customs_released_carrier,
    DATE_CODE_FULL_OUTGATE_DISCHARGE_PORT=>:ord_asn_gate_out,
    DATE_CODE_ON_RAIL_DESTINATION=>:ord_asn_on_rail_destination,
    DATE_CODE_ARRIVED=>:ord_asn_arrived,
    DATE_CODE_DEPARTED=>:ord_asn_departed,
    DATE_CODE_DISCHARGED=>:ord_asn_discharged,
    DATE_CODE_LOADED_AT_PORT=>:ord_asn_loaded_at_port,
    DATE_CODE_ARRIVE_AT_TRANSSHIP_PORT=>:ord_asn_arrive_at_transship_port,
    DATE_CODE_DEPART_FROM_TRANSSHIP_PORT=>:ord_asn_depart_from_transship_port
  }

  # Codes that are unique to the prod system, plus the common codes.
  PROD_DATE_CDEF_MAP_ORDER = {
    DATE_CODE_EMPTY_OUT_GATE_AT_ORIGIN=>:ord_asn_empty_out_gate_at_origin,
    DATE_CODE_FULL_INGATE_AT_ORIGIN=>:ord_asn_gate_in,
    DATE_CODE_CONTAINER_UNLOADED=>:ord_asn_container_unloaded,
    DATE_CODE_AVAILABLE_FOR_DELIVERY=>:ord_asn_available_for_delivery,
    DATE_CODE_FULL_INGATE=>:ord_asn_full_ingate,
    DATE_CODE_RAIL_ARRIVED_DESTINATION=>:ord_asn_rail_arrived_destination,
    DATE_CODE_BARGE_DEPART=>:ord_asn_barge_depart,
    DATE_CODE_BARGE_ARRIVE=>:ord_asn_barge_arrive,
    DATE_CODE_FCR_CREATED=>:ord_asn_fcr_created
  }.merge(COMMON_DATE_CDEF_MAP_ORDER)

  # Codes that are unique to the test system, plus the common codes.
  TEST_DATE_CDEF_MAP_ORDER = {
    TEST_DATE_CODE_EMPTY_OUT_GATE_AT_ORIGIN=>:ord_asn_empty_out_gate_at_origin,
    TEST_DATE_CODE_FULL_INGATE_AT_ORIGIN=>:ord_asn_gate_in,
    TEST_DATE_CODE_CONTAINER_UNLOADED=>:ord_asn_container_unloaded,
    TEST_DATE_CODE_AVAILABLE_FOR_DELIVERY=>:ord_asn_available_for_delivery,
    TEST_DATE_CODE_FULL_INGATE=>:ord_asn_full_ingate,
    TEST_DATE_CODE_RAIL_ARRIVED_DESTINATION=>:ord_asn_rail_arrived_destination,
    TEST_DATE_CODE_BARGE_DEPART=>:ord_asn_barge_depart,
    TEST_DATE_CODE_BARGE_ARRIVE=>:ord_asn_barge_arrive,
    TEST_DATE_CODE_FCR_CREATED=>:ord_asn_fcr_created
  }.merge(COMMON_DATE_CDEF_MAP_ORDER)

  def self.parse_file data, log, opts={}
    parse_dom REXML::Document.new(data), log, opts
  end

  def self.parse_dom dom, log, opts={}
    self.new.parse_dom dom, log, opts[:key]
  end

  def parse_dom dom, log, s3_key
    root = dom.root
    log.error_and_raise "Bad root element name \"#{root.name}\". Expecting ASNMessage." unless root.name=='ASNMessage'
    # Although the XML structure allows for multiple ASN elements, there will be only one.
    elem_asn = root.elements['ASN']

    log.company = Company.where(system_code: "LUMBER").first

    # The 'shipping order number' value from the XML is the value we'll use to look up the shipment.  This is kind of a
    # confusing label, as it's meant to match to the shipment's reference number (i.e. main key field for the
    # shipment), not an order number.  Note that the shipping order number should be the same for
    # all line items.  One ASN file represents one shipment.
    shipping_order_number = et(REXML::XPath.first(elem_asn,'Container/LineItems'), 'ShippingOrderNumber')
    log.add_identifier InboundFileIdentifier::TYPE_SHIPMENT_NUMBER, shipping_order_number
    xml_timestamp = xml_created_timestamp(root)

    errors = []
    need_to_roll_back = false
    shipment_found = false
    get_shipment(shipping_order_number) do |shp|
      shipment_found = true

      log.set_identifier_module_info InboundFileIdentifier::TYPE_SHIPMENT_NUMBER, Shipment.to_s, shp.id

      # Don't update the shipment if the data in it is outdated
      if shp.last_exported_from_source && shp.last_exported_from_source > xml_timestamp
        log.add_info_message "Shipment not updated: file contained outdated info."
        return
      end

      update_shipment shp, elem_asn, xml_timestamp, errors, log

      shipment_error_count = errors.length
      order_snapshots = Set.new
      get_orders(elem_asn, errors, log).each do |ord_num, ord_hash|
        if errors.length == shipment_error_count
          if !need_to_roll_back
            ord = ord_hash[:order]
            log.add_identifier(InboundFileIdentifier::TYPE_PO_NUMBER, ord.order_number, module_type:Order.to_s, module_id:ord.id)
            update_order ord, ord_hash[:element], shp
            order_snapshots << ord
          end
        else
          need_to_roll_back = true
        end
      end

      if need_to_roll_back
        # If we're rolling back, exclude the error messages related to missing shipment lines and containers, since
        # that would be likely to confuse.  Those error messages mention creating new lines and containers.
        errors = errors.select { |msg| msg.match(/^ASN Failed/) }
        raise ActiveRecord::Rollback
      else
        # Aggregate all the snapshots here, this is because a snapshot writes data to s3, which we don't want out there if the update is getting rolled back
        user = User.integration
        shp.create_snapshot user, nil, s3_key
        order_snapshots.each {|ord| ord.create_snapshot user, nil, s3_key}
      end
    end

    if !shipment_found
      # We're going to still want to evaluate the order elements, since those may also result in errors that need to be reported..but we won't update anything on them
      msg = "ASN Failed because shipment not found in database: #{shipping_order_number}."
      errors << msg
      log.add_reject_message msg
      get_orders(elem_asn, errors, log)
    end

    if errors.length > 0
      body_text = "Errors were encountered while parsing ASN file for #{shipping_order_number}.<br><br>#{errors.uniq.join("<br>")}"
      OpenMailer.send_simple_html("ll-support@vandegriftinc.com", "Lumber GTN ASN Parser Errors: #{shipping_order_number}", body_text.html_safe).deliver!
    end

    nil
  end

  private

    def xml_created_timestamp xml_root
      Time.zone.parse(xml_root.text "TransactionInfo/Created")
    rescue 
      # This should never really be nil, but I don't want to assume as much since it's more important 
      # that the data in this xml is processed than the actual file timestamp is recorded.
      nil
    end

    def update_order ord, elem_line_element, shp
      get_order_dates(elem_line_element).each do |cdef,val|
        ord.update_custom_value!(cdef,val)
      end

      ord.update_custom_value!(cdefs[:ord_bill_of_lading], shp.master_bill_of_lading)
      ord.update_custom_value!(cdefs[:ord_bol_date], shp.bol_date)

      # Copy shipment detail-level values to the matching PO lines for simplified reporting purposes.
      shp.shipment_lines.each do |shp_line|
        ord_line = ord.order_lines.find {|ol| shp_line.piece_sets.first.try(:order_line_id) == ol.id }
        # This shipment line could be on another PO than the current one (in the event multiple POs are involved
        # with the same shipment).
        if ord_line
          update_order_line_cdefs shp_line, ord_line
        end
      end

      ord.save!
      ord
    end

    def get_order_dates elem_line_element
      found_dates = {}
      production = MasterSetup.get.production?
      REXML::XPath.each(elem_line_element,'MilestoneMessage/OneReferenceMultipleMilestones/MilestoneInfo') do |el|
        code = et(el,'MilestoneTypeCode')
        cdef = cdefs[production ? PROD_DATE_CDEF_MAP_ORDER[code] : TEST_DATE_CDEF_MAP_ORDER[code]]
        date = parse_date(el)
        next unless cdef && date
        found_dates[cdef] = date
      end
      found_dates
    end

    def parse_date el
      inner_el = REXML::XPath.first(el,'MilestoneTime[@timeZone="LT"]')
      return nil if inner_el.blank?
      date_attr = inner_el.attribute('dateTime')
      return nil if date_attr.blank?
      date_str = date_attr.value
      return nil if date_str.blank?
      DateTime.iso8601(date_str)
    end

    def get_orders elem_asn, errors, log
      r = {}
      REXML::XPath.each(elem_asn,'Container/LineItems') do |el|
        order_number = et(el,'PONumber')
        if !order_number.blank?
          r[order_number] = {element:el}
        end
      end
      orders = Order.includes(:custom_values).where('order_number IN (?)',r.keys.to_a).to_a
      if r.size != orders.size
        missing_order_numbers = r.keys.to_a - orders.map(&:order_number)
        msg = "ASN Failed because order(s) not found in database: #{missing_order_numbers.join(', ')}."
        errors << msg
        log.add_reject_message msg
      else
        orders.each {|ord| r[ord.order_number][:order] = ord}
      end
      r
    end

    # Look up the shipment matching the 'shipping order number' value from the XML, which is the shipment reference
    # number.  Error if not found.
    def get_shipment shipping_order_number
      shp = Shipment.includes(:custom_values).where(reference:shipping_order_number).first
      if shp
        Lock.db_lock(shp) do
          yield shp
        end
      end

      shp
    end

    def update_shipment shp, elem_asn, asn_sent_date, errors, log
      production = MasterSetup.get.production?

      shp.last_exported_from_source = asn_sent_date
      shp.empty_out_at_origin_date = get_shipment_date elem_asn, (production ? DATE_CODE_EMPTY_OUT_GATE_AT_ORIGIN : TEST_DATE_CODE_EMPTY_OUT_GATE_AT_ORIGIN)
      shp.est_arrival_port_date = get_shipment_date elem_asn, DATE_CODE_EST_ARRIVAL_DISCHARGE
      shp.est_departure_date = get_shipment_date elem_asn, DATE_CODE_EST_DEPARTURE
      shp.cargo_on_hand_date = get_shipment_date elem_asn, (production ? DATE_CODE_FULL_INGATE_AT_ORIGIN : TEST_DATE_CODE_FULL_INGATE_AT_ORIGIN)
      shp.empty_return_date = get_shipment_date elem_asn, DATE_CODE_EMPTY_RETURN
      shp.delivered_date = get_shipment_date elem_asn, DATE_CODE_DELIVERED
      shp.container_unloaded_date = get_shipment_date elem_asn, (production ? DATE_CODE_CONTAINER_UNLOADED : TEST_DATE_CODE_CONTAINER_UNLOADED)
      shp.carrier_released_date = get_shipment_date elem_asn, DATE_CODE_CARRIER_RELEASED
      shp.customs_released_carrier_date = get_shipment_date elem_asn, DATE_CODE_CUSTOMS_RELEASED_CARRIER
      shp.available_for_delivery_date = get_shipment_date elem_asn, (production ? DATE_CODE_AVAILABLE_FOR_DELIVERY : TEST_DATE_CODE_AVAILABLE_FOR_DELIVERY)
      shp.full_ingate_date = get_shipment_date elem_asn, (production ? DATE_CODE_FULL_INGATE : TEST_DATE_CODE_FULL_INGATE)
      shp.full_out_gate_discharge_date = get_shipment_date elem_asn, DATE_CODE_FULL_OUTGATE_DISCHARGE_PORT
      shp.on_rail_destination_date = get_shipment_date elem_asn, DATE_CODE_ON_RAIL_DESTINATION
      shp.inland_port_date = get_shipment_date elem_asn, (production ? DATE_CODE_RAIL_ARRIVED_DESTINATION : TEST_DATE_CODE_RAIL_ARRIVED_DESTINATION)
      shp.arrival_port_date = get_shipment_date elem_asn, DATE_CODE_ARRIVED
      shp.departure_date = get_shipment_date elem_asn, DATE_CODE_DEPARTED
      shp.full_container_discharge_date = get_shipment_date elem_asn, DATE_CODE_DISCHARGED
      shp.confirmed_on_board_origin_date = get_shipment_date elem_asn, DATE_CODE_LOADED_AT_PORT
      shp.arrive_at_transship_port_date = get_shipment_date elem_asn, DATE_CODE_ARRIVE_AT_TRANSSHIP_PORT
      shp.departure_last_foreign_port_date = get_shipment_date elem_asn, DATE_CODE_DEPART_FROM_TRANSSHIP_PORT
      shp.barge_depart_date = get_shipment_date elem_asn, (production ? DATE_CODE_BARGE_DEPART : TEST_DATE_CODE_BARGE_DEPART)
      shp.barge_arrive_date = get_shipment_date elem_asn, (production ? DATE_CODE_BARGE_ARRIVE : TEST_DATE_CODE_BARGE_ARRIVE)
      shp.fcr_created_final_date = get_shipment_date elem_asn, (production ? DATE_CODE_FCR_CREATED : TEST_DATE_CODE_FCR_CREATED)
      shp.bol_date = get_shipment_date_by_xpath(elem_asn, "Container/LineItems/ReferenceDates[ReferenceDateType='BlDate1']/ReferenceDate") { |el| DateTime.iso8601(el.text) }
      shp.vessel_carrier_scac = REXML::XPath.first(elem_asn, "PartyInfo[Type='Carrier']/Code").try(:text)
      shp.voyage = et(elem_asn, 'Voyage')
      shp.vessel = et(elem_asn, 'Vessel')
      shp.lading_port = get_port elem_asn, 'PortOfLoading'
      shp.unlading_port = get_port elem_asn, 'PortOfDischarge'
      shp.final_dest_port = get_port elem_asn, 'BLDestination'

      bill_lading = get_bill_of_lading elem_asn
      # Don't clear an existing BOL.  (Not sure how necessary the no-clearing rule is, but it was in an older version
      # of this parser. - WBH, 2018)
      if !bill_lading.blank?
        shp.master_bill_of_lading = bill_lading
      end

      elem_asn.elements.each('Container') do |elem_cont|
        container = add_or_update_container elem_cont, shp, errors, log
        elem_cont.elements.each('LineItems') do |elem_line_item|
          add_or_update_shipment_line elem_line_item, shp, container, errors, log
        end
      end

      shp.save!
      shp
    end

    # Bill of Lading should be the same for all line items.  One ASN file represents one shipment.
    def get_bill_of_lading elem_asn
      et(REXML::XPath.first(elem_asn,'Container/LineItems'), 'BLNumber')
    end

    def update_shipment_custom_date shp, elem_asn, date_code, cdef_key
      val = get_shipment_date elem_asn, date_code
      cdef = cdefs[cdef_key]
      shp.update_custom_value!(cdef,val)
    end

    # Gets the latest date from the XML matching the provided code.  Container-level dates from the XML are stored
    # in the shipment ('header-level'), requiring this.
    def get_shipment_date elem_asn, code
      get_shipment_date_by_xpath(elem_asn, "Container/LineItems/MilestoneMessage/OneReferenceMultipleMilestones/MilestoneInfo[MilestoneTypeCode='#{code}']") { |el| parse_date(el) }
    end

    def get_shipment_date_by_xpath elem_asn, xpath
      latest_date = nil
      REXML::XPath.each(elem_asn, xpath) do |el|
        date = yield el
        if !latest_date || (date && date > latest_date)
          latest_date = date
        end
      end
      latest_date
    end

    def get_port elem_asn, field_name
      port = nil
      un_locode = REXML::XPath.first(elem_asn, "#{field_name}/CityCode[@Qualifier='UN']").try(:text)
      if un_locode && !un_locode.blank?
        port = Port.where(unlocode:un_locode).first
      end
      port
    end

    def add_or_update_container elem_cont, shp, errors, log
      container_number = et(elem_cont, 'ContainerNumber')
      container = shp.containers.find {|c| c.container_number == container_number }
      if !container
        container = shp.containers.build(container_number:container_number)
        msg = "Shipment did not contain a container #{container_number}. A container record was created."
        errors << msg
        log.add_warning_message msg
      end
      container.container_size = convert_gtn_equipment_type(et(elem_cont, 'ContainerType'))
      container.seal_number = et(elem_cont, 'SealNumber')
      container.weight = et(elem_cont, 'ActualWeight')
      container
    end

    # Converts GTN equipment type code (value) to VFI code (key) using the data cross reference table.
    def convert_gtn_equipment_type equipment_type
      DataCrossReference.where(cross_reference_type:DataCrossReference::LL_GTN_EQUIPMENT_TYPE, value:equipment_type).pluck(:key).first
    end

    def add_or_update_shipment_line elem_line_item, shp, container, errors, log
      po_number = et(elem_line_item, 'PONumber')
      # Strip off leading zeroes.
      po_line_number = et(elem_line_item, 'LineItemNumber').to_i
      if !po_number.blank? && po_line_number > 0
        po_line = OrderLine.joins(:order).where(line_number:po_line_number, orders:{order_number:po_number}).first
        if po_line
          shp_line = shp.shipment_lines.find {|sl| sl.piece_sets.first.try(:order_line_id) == po_line.id }
          if !shp_line
            shp_line = shp.shipment_lines.build(shipment:shp, product:po_line.product, container:container, linked_order_line_id:po_line.id)
            msg = "Shipment did not contain a manifest line for PO #{po_number}, line #{po_line_number}. A manifest line record was created."
            errors << msg
            log.add_warning_message msg
          end
        else
          msg = "Shipment did not contain a manifest line for PO #{po_number}, line #{po_line_number}. A manifest line record could NOT be created because no matching PO line could be found."
          errors << msg
          log.add_warning_message msg
        end

        if shp_line
          # Quantity plus linked order line ID being set in this line will result in the creation of a PieceSet
          # against the line (if it doesn't already have one).
          shp_line.quantity = BigDecimal(et(elem_line_item, 'Quantity').try(:to_s))
          shp_line.cbms = et(elem_line_item, 'Volume').try(:to_f)
          if shp_line.persisted?
            piece_set = shp_line.piece_sets.first
            piece_set.quantity = shp_line.quantity
            piece_set.save!
          end
        end
      else
        msg = "LineItems in this file are missing PONumber and LineItemNumber values necessary to connect to shipment lines."
        errors << msg
        log.add_warning_message msg
      end
    end

    # For reporting purposes, a number of shipment line-level values are being mapped to the order lines.
    # Order lines are not split over multiple shipments for Lumber.  We can assume 1:1 matching.
    def update_order_line_cdefs shp_line, ord_line
      ord_line.update_custom_value!(cdefs[:ordln_shpln_line_number], shp_line.line_number)
      ord_line.update_custom_value!(cdefs[:ordln_shpln_product], shp_line.product.try(:unique_identifier))
      ord_line.update_custom_value!(cdefs[:ordln_shpln_quantity], shp_line.quantity)
      ord_line.update_custom_value!(cdefs[:ordln_shpln_cartons], shp_line.carton_qty)
      ord_line.update_custom_value!(cdefs[:ordln_shpln_volume], shp_line.cbms)
      ord_line.update_custom_value!(cdefs[:ordln_shpln_gross_weight], shp_line.gross_kgs)
      ord_line.update_custom_value!(cdefs[:ordln_shpln_container_number], shp_line.container.try(:container_number))
    end

    def cdefs 
      @cdefs ||= self.class.prep_custom_definitions [
        :ord_asn_arrived,:ord_asn_departed,:ord_asn_discharged,:ord_asn_empty_return,:ord_asn_fcr_created,:ord_asn_gate_in,
        :ord_asn_gate_out,:ord_asn_loaded_at_port,:ord_asn_empty_out_gate_at_origin,:ord_asn_est_arrival_discharge,
        :ord_asn_est_departure,:ord_asn_delivered,:ord_asn_container_unloaded,:ord_asn_carrier_released,
        :ord_asn_customs_released_carrier,:ord_asn_available_for_delivery,:ord_asn_full_ingate,
        :ord_asn_on_rail_destination,:ord_asn_rail_arrived_destination,:ord_asn_arrive_at_transship_port,
        :ord_asn_depart_from_transship_port,:ord_asn_barge_depart,:ord_asn_barge_arrive,:ord_bill_of_lading,:ord_bol_date,
        :ordln_shpln_line_number,:ordln_shpln_product,:ordln_shpln_quantity,:ordln_shpln_cartons,:ordln_shpln_volume,
        :ordln_shpln_gross_weight,:ordln_shpln_container_number
      ]
    end

end; end; end; end