require 'open_chain/custom_handler/xml_helper'
require 'open_chain/custom_handler/j_jill/j_jill_support.rb'
module OpenChain; module CustomHandler; module JJill; class JJillEcellerateXmlParser
  include OpenChain::CustomHandler::XmlHelper
  include OpenChain::CustomHandler::JJill::JJillSupport

  def self.parse_file data, log, opts={}
    parse_dom REXML::Document.new(data), log
  end

  def self.parse_dom dom, log, opts={}
    self.new(opts).parse_dom dom, log
  end

  def initialize opts={}
    @jill = Company.find_by_ecellerate_customer_number 'JILSO'
    @user = User.find_by_username 'integration'
  end

  def parse_dom dom, log
    log.error_and_raise "Company with system code #{UID_PREFIX} not found." unless @jill
    log.company = @jill

    ActiveRecord::Base.transaction do
      root = dom.root
      trans_id = et(root,'TransactionId')
      log.add_identifier InboundFileIdentifier::TYPE_SHIPMENT_NUMBER, trans_id

      trans_date = ed(root,'TransactionDateTime')
      mbol = et(root,'MasterBillNumber')
      hbol = et(root,'HouseBillNumber')

      shipment_lines_by_key = {}
      shipment_line_cursor = 1

      shp_ref = "#{UID_PREFIX}-#{trans_id}"
      s = Shipment.find_by_importer_id_and_reference @jill.id, shp_ref
      if s
        log.set_identifier_module_info InboundFileIdentifier::TYPE_SHIPMENT_NUMBER, Shipment.to_s, s.id
      else
        s = Shipment.new(importer_id:@jill.id,reference:shp_ref)
      end
      s.master_bill_of_lading = mbol
      s.house_bill_of_lading = hbol
      s.mode = et(root,'TransportationMethod')

      s.shipment_lines.each do |sl|
        ol = sl.order_lines.first
        k = shipment_line_key(sl.container,ol.order.customer_order_number,ol.sku)
        shipment_lines_by_key[k] = sl
      end

      #skip if the document is older than the last one processed for this shipment
      if s.last_exported_from_source && s.last_exported_from_source > trans_date
        log.add_info_message "Shipment not updated: file contained outdated info."
        return
      end

      #load non containerized items
      REXML::XPath.each(root,'/ShipNotice/Items/Item') do |item|
        add_shipment_line shipment_lines_by_key, s, item, shipment_line_cursor, log
        shipment_line_cursor += 1
      end

      #load non containerized items
      REXML::XPath.each(root,'/ShipNotice/Containers/Container') do |cont_el|
        c_num = "#{et(cont_el,'EquipmentInitial')}#{et(cont_el,'EquipmentNumber')}"
        cont = s.containers.find_by_container_number c_num
        cont = s.containers.build(container_number:c_num) unless cont
        cont.seal_number = et(cont_el,'SealNumber1')
        cw = et(cont_el,'ChargeableWeight')
        cont.weight = BigDecimal(cw).round unless cw.blank?
        cont.container_size = et(cont_el,'EquipmentTypeCode')
        REXML::XPath.each(cont_el,'Items/Item') do |item|
          add_shipment_line shipment_lines_by_key, s, item, shipment_line_cursor, log, cont
          shipment_line_cursor += 1
        end
      end
      s.save!
      log.set_identifier_module_info InboundFileIdentifier::TYPE_SHIPMENT_NUMBER, Shipment.to_s, s.id

      EntitySnapshot.create_from_entity s, @user
    end
  end

  private

  def add_shipment_line shipment_lines_by_key, shipment, item_el, shipment_line_number, log, container = nil
    po = et(item_el,'PurchaseOrderNumber')
    qty = et(item_el,'QuantityShipped')
    sku = et(item_el,'SKUNumber')
    key = shipment_line_key(container,po,sku)

    sl = shipment_lines_by_key[key]
    if sl.nil?
      ol = find_order_line(po, sku, log)
      sl = shipment.shipment_lines.build(product_id:ol.product_id)
      sl.linked_order_line_id = ol.id
      shipment_lines_by_key[key] = sl
      sl.line_number = shipment_line_number
    elsif sl.line_number != shipment_line_number
      log.reject_and_raise "Shipment Line with ID #{sl.id} had line number #{sl.line_number} instead of expected line number #{shipment_line_number}"
    end
    sl.container = container
    sl.quantity = qty
  end

  def shipment_line_key container, po, sku
    #assuming that there will only be one instance of a PO/SKU in a container
    "#{container ? container.id : "NONE"}-#{po}-#{sku}"
  end

  def find_order_line po, sku, log
    @order_cache ||= {}
    ord = Order.includes(:order_lines).where(order_number:"#{UID_PREFIX}-#{po}", importer_id: @jill.id).first
    log.reject_and_raise "Order #{po} not found" unless ord
    ol = ord.order_lines.find {|ol| ol.sku == sku}
    log.reject_and_raise "Order #{po} does not have SKU #{sku}" unless ol
    ol
  end

  #get date from element
  def ed parent, element_name
    txt = et parent, element_name
    txt.blank? ? nil : Time.iso8601(txt)
  end
end; end; end; end