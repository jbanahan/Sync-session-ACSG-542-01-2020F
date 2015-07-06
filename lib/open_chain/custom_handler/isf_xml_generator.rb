require 'open_chain/xml_builder'
require 'open_chain/ftp_file_support'

module OpenChain; module CustomHandler; class ISFXMLGenerator
  include OpenChain::XmlBuilder
  include OpenChain::FtpFileSupport

  EdiLine = Struct.new('EdiLine',:order_number, :hts_number, :country_of_origin, :container_number)

  def self.generate_and_send_for_shipment_id(shipment_id)
    new(shipment_id).generate_and_send!
  end

  def initialize(shipment_id)
    @shipment = Shipment.find(shipment_id)
    raise 'Shipment is missing information required for ISF!' unless @shipment.valid_isf?
    @edi_lines = Set.new

    @shipment.shipment_lines.each do |line|
      @edi_lines << EdiLine.new(
        order_number:line.order_lines.first.order.customer_order_number,
        hts_number: line.product.classifications.where(country_id:Country.where(iso_code:'US').pluck(:id)).tariff_records.first.hts_code,
        country_of_origin: line.country_of_origin,
        container_number: line.container.container_number
      )
    end
  end

  def generate_and_send!
    document = generate
    send! document
  end

  private

  def send!(file)
    Tempfile.open(["#{@shipment.reference}-ISF-#{Time.now.iso8601}", ".xml"]) do |fout|
      file.write fout
      fout.flush
      fout.rewind
      ftp_file fout
    end
  end

  def generate(options={})
    doc, root = build_xml_document "IsfEdiUpload", root_content:'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:isf="http://isf.kewill.com/ws/upload/"'
    add_element root, 'CUSTOMER_ACCT_CD', options[:isf_cust_acct]
    add_element root, 'USER_NAME', options[:isf_username]
    add_element root, 'PASSWORD', options[:isf_password]
    add_element root, 'DATE_CREATED', Time.now.in_time_zone('US/Eastern').iso8601
    add_element root, 'EDI_TXN_IDENTIFIER', @shipment.id
    add_element root, 'ACTION_CD', @shipment.isf_sent_at ? 'R' : 'A'
    add_element root, 'IMPORTER_ACCT_CD', @shipment.importer.alliance_customer_number
    add_element root, 'OWNER_ACCT_CD', options[:isf_cust_acct]
    add_element root, 'EST_LOAD_DATE'
    add_element root, 'BOOKING_NBR', @shipment.booking_number

    if @shipment.house_bill_of_lading.present?
      edi_bill_lading = add_element root, 'EdiBillLading'
      add_element edi_bill_lading, 'HOUSE_BILL_NBR', @shipment.house_bill_of_lading[4..-1]
      add_element edi_bill_lading, 'HOUSE_BILL_SCAC_CD', @shipment.house_bill_of_lading[0...4]
    end

    if @shipment.master_bill_of_lading.present?
      edi_bill_lading = add_element root, 'EdiBillLading'
      add_element edi_bill_lading, 'MASTER_BILL_NBR', @shipment.master_bill_of_lading[4..-1]
      add_element edi_bill_lading, 'MASTER_BILL_SCAC_CD', @shipment.master_bill_of_lading[0...4]
    end

    @shipment.containers.each do |container|
      container_root = add_element root, 'Container'
      add_element container_root, 'CONTAINER_NBR', container.container_number
      add_element container_root, 'EQUIPMENT_CD', 'CN'
    end

    importer_entity = add_element root, 'EdiEntity'
    add_element importer_entity, 'ENTITY_TYPE_CD', 'IM'
    add_element importer_entity, 'BROKERAGE_ACCT_CD', @shipment.importer.alliance_customer_number

    consignee_entity = add_element root, 'EdiEntity'
    add_element consignee_entity, 'ENTITY_TYPE_CD', 'CS'
    add_element consignee_entity, 'ENTITY_ID', @shipment.consignee.irs_number
    add_element consignee_entity, 'ENTITY_ID_TYPE_CD', 'EI'
    add_element consignee_entity, 'NAME', @shipment.consignee.name

    #TODO: Manufacturers

    add_address_entity root, @shipment.seller_address, 'SE'
    add_address_entity root, @shipment.buyer_address, 'BY'
    add_address_entity root, @shipment.ship_to_address, 'ST'
    add_address_entity root, @shipment.container_stuffing_address, 'LG'
    add_address_entity root, @shipment.consolidator_address, 'CS'

    @edi_lines.each do |line|
      line_element = add_element root, 'EdiLine'
      add_element line_element, 'PO_NBR', line.order_number
      add_element line_element, 'TARIFF_CD', line.hts_number
      add_element line_element, 'ORIGIN_COUNTRY_CD', line.country_of_origin
      add_element line_element, 'CONTAINER_NBR', line.container_number
    end

    doc
  end

  def add_address_entity(root, address, entity_type, index=nil)
    entity = add_element root, 'EdiEntity'
    add_element entity, 'ENTITY_TYPE_CD', entity_type
    add_element entity, 'ENTITY_ID', index if index
    add_element entity, 'NAME', address.name
    add_element entity, 'ADDRESS_1', address.line_1.gsub(/[^0-9A-Za-z]/, " ")
    add_element entity, 'ADDRESS_2', address.line_2.gsub(/[^0-9A-Za-z]/, " ") if address.line_2
    add_element entity, 'CITY', address.city.gsub(/[^0-9A-Za-z]/, " ")
    add_element entity, 'COUNTRY_SUBENTITY_CD', address.state
    add_element entity, 'POSTAL_CD', address.postal_code
    add_element entity, 'COUNTRY_CD', address.country.iso_code
  end

  def ftp_credentials
    # TODO: get real credentials
    connect_vfitrack_net 'to_ecs/315'
  end
end; end; end