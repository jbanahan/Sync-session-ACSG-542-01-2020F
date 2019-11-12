require 'open_chain/xml_builder'
require 'open_chain/custom_handler/lumber_liquidators/lumber_custom_definition_support'

module OpenChain; module CustomHandler; module LumberLiquidators; class LumberExpeditorsBookingXmlGenerator
  extend OpenChain::XmlBuilder
  include OpenChain::CustomHandler::LumberLiquidators::LumberCustomDefinitionSupport

  UOM_MAP ||= {
    'FTK'=>'SFT',
    'FT2'=>'SFT',
    'FOT'=>'FT'
  }
  CDEF_LIST ||= [:ord_country_of_origin,:prod_merch_cat]
  def self.generate_xml shipment, cdefs = self.prep_custom_definitions(CDEF_LIST)
    doc, root = build_xml_document('booking')
    add_element(root,'reference',shipment.reference)
    add_requested_equipment(root,shipment)
    add_element(root,'vendor-system-code',shipment.vendor.system_code)
    add_element(root,'consignee-name','Lumber Liquidators')
    add_date(root,'cargo-ready-date',shipment.cargo_ready_date)
    add_date(root,'canceled-date',shipment.canceled_date) if shipment.canceled_date
    add_mode(root,shipment)
    add_service_type(root,shipment)
    add_booking_lines(root,shipment,cdefs)
    ['stuffing','seller','manufacturer'].each do |type|
      add_address(root,shipment.ship_from,type)
    end
    usa = Country.new
    usa.iso_code = 'US'
    ll_corp = Address.new(
      name:'Lumber Liquidators',
      line_1:'4901 Bakers Mill Lane',
      city: 'Richmond',
      state: 'VA',
      postal_code:'23230-2431',
      country:usa
    )
    add_address(root,ll_corp,'buyer')
    add_origin_port(root,shipment)
    doc
  end

  def self.add_booking_lines parent, shipment, cdefs
    lineWrapper = add_element(parent,'booking-lines')
    shipment.booking_lines.each do |bl|
      lineEl = add_element(lineWrapper,'booking-line')
      add_element(lineEl,'order-number',bl.order_line.order.order_number)
      add_element(lineEl,'order-line-number',bl.order_line.line_number)
      add_element(lineEl,'part-number',bl.product.unique_identifier)
      add_element(lineEl,'part-name',bl.product.name)
      add_element(lineEl,'quantity',bl.quantity.to_s)
      add_element(lineEl,'unit-price',bl.order_line.price_per_unit)
      add_element(lineEl,'currency',bl.order_line.order.currency)
      add_element(lineEl,'country-of-origin',bl.order_line.order.custom_value(cdefs[:ord_country_of_origin]))
      add_element(lineEl,'department',bl.product.custom_value(cdefs[:prod_merch_cat]))
      add_element(lineEl,'inco-terms',bl.order_line.order.terms_of_sale)
      add_date(lineEl,'item-early-ship-date',bl.order_line.order.ship_window_start)
      add_date(lineEl,'item-late-ship-date',bl.order_line.order.ship_window_end)
      add_unit_of_measure(lineEl,bl)
      add_hts_code(lineEl,bl)
      add_warehouse_code(lineEl,bl)
    end
  end

  def self.add_origin_port parent, shipment
    str = ''
    port = shipment.first_port_receipt
    str = port.unlocode
    add_element(parent,'origin-port',str)
  end
  def self.add_address parent, address, type
    aEl = add_element(parent,'address')
    aEl.attributes['type'] = type
    add_element(aEl,'name',address.name)
    add_element(aEl,'line-1',address.line_1)
    add_element(aEl,'line-2',address.line_2)
    add_element(aEl,'line-3',address.line_3)
    add_element(aEl,'city',address.city)
    add_element(aEl,'state',address.state)
    add_element(aEl,'postal-code',address.postal_code)
    iso = address.country ? address.country.iso_code : ''
    add_element(aEl,'country',iso)
  end

  def self.add_warehouse_code parent, booking_line
    str = ''
    ship_to = booking_line.order_line.ship_to
    str = ship_to.system_code if ship_to
    add_element(parent,'warehouse',str)
  end

  def self.add_hts_code parent, booking_line
    str = ''
    p = booking_line.product
    if p
      cls = booking_line.product.classifications.find {|c| c.country.iso_code == 'US'}
      if cls
        tr = cls.tariff_records.find {|trec| !trec.hts_1.blank?}
        if tr
          str = tr.hts_1
        end
      end
    end
    add_element(parent,'hts-code',str)
  end
  def self.add_unit_of_measure parent, booking_line
    raw_uom = booking_line.order_line.unit_of_measure
    translated_uom = UOM_MAP[raw_uom]
    translated_uom = raw_uom if translated_uom.nil?
    add_element(parent,'unit-of-measure',translated_uom)
  end

  def self.add_mode parent, shipment
    mode = shipment.booking_mode
    mode = '' if mode.blank?
    mode = mode.upcase
    raise "Invalid mode, only Air and Ocean are allowed, got #{shipment.booking_mode}" unless ['AIR','','OCEAN'].include?(mode)
    add_element(parent,'mode',mode)
  end

  def self.add_service_type parent, shipment
    st = shipment.booking_shipment_type
    st = '' if st.blank?
    st = st.upcase
    raise "Invalid service type, only CY, CFS or AiIR are allowed, got #{shipment.booking_shipment_type}" unless ['CY','CFS','AIR'].include?(st)
    add_element(parent,'service-type',st)
  end

  def self.add_date parent, name, date
    str = date ? date.strftime('%Y%m%d') : ''
    add_element(parent,name,str)
  end

  def self.add_requested_equipment root, shipment
    pieces = shipment.get_requested_equipment_pieces
    return if pieces.empty?
    reqEl = add_element(root,'requested-equipment')
    pieces.each do |p|
      el = add_element(reqEl,'equipment',p[0])
      el.attributes['type'] = p[1]
    end
    nil
  end
end; end; end; end
