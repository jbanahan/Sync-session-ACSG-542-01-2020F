require 'open_chain/custom_handler/fenix_nd_invoice_generator'
require 'open_chain/custom_handler/vfitrack_custom_definition_support'

module OpenChain; module CustomHandler; module Advance; class CarquestFenixNdInvoiceGenerator < OpenChain::CustomHandler::FenixNdInvoiceGenerator
  include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport

  def generate_invoice_and_send shipment, sync_record
    generate_invoices(shipment).each do |invoice|
      generate_and_send(invoice, sync_record: sync_record)
    end
    nil
  end

  def generate_invoices shipment
    invoices = []
    split_lines_by_invoice_number(shipment).each_pair do |invoice_number, shipment_lines|
      invoices << build_invoice(shipment_lines)
    end

    invoices
  end

  # This is an override of the default to provide actual CQ information in the file, instead of "generic"
  def invoice_header_map
    super.merge( {
      importer: lambda {|i| convert_company_to_hash(i.importer) }
    } )
  end

  def build_invoice shipment_lines
    first_line = shipment_lines.first
    shipment = first_line.shipment

    inv = CommercialInvoice.new 
    inv.invoice_number = first_line.invoice_number
    inv.invoice_date = ActiveSupport::TimeZone["America/New_York"].now.to_date
    inv.importer = convert_address_to_company(shipment.ship_to)
    inv.consignee = shipment.consignee
    inv.vendor = convert_address_to_company(shipment.ship_from)
    # Not a typo, I mean to pull the house to the master here.
    inv.master_bills_of_lading = first_line.shipment.house_bill_of_lading

    shipment_lines.each do |shipment_line|
      inv.commercial_invoice_lines << build_invoice_line(shipment_line)
    end

    inv.country_origin_code = inv.commercial_invoice_lines.first.country_origin_code

    inv
  end

  def build_invoice_line shipment_line
    line = CommercialInvoiceLine.new

    order_line = shipment_line.order_lines.first
    line.part_number = order_line.product.custom_value(cdefs[:prod_sku_number])
    line.po_number = order_line.order.customer_order_number
    line.quantity = shipment_line.quantity
    line.unit_price = order_line.price_per_unit
    line.country_origin_code = order_line.country_of_origin

    tariff = line.commercial_invoice_tariffs.build
    tariff.hts_code = order_line.product.hts_for_country(ca).first
    tariff.tariff_description = order_line.product.name

    line
  end

  def convert_address_to_company address
    return nil unless address

    c = Company.new name: address.name
    c.addresses << address

    c
  end

  def invoice_totals shipment_lines
    totals = {units: BigDecimal("0"), weight: BigDecimal("0")}
  end

  def split_lines_by_invoice_number shipment
    invoices = Hash.new do |h, k|
      h[k] = []
    end

    shipment.shipment_lines.each do |line|
      invoices[line.invoice_number] << line unless line.invoice_number.blank?
    end

    invoices
  end

  def ca
    @ca ||= Country.where(iso_code: "CA").first
  end

  def cdefs
    @cdefs ||= self.class.prep_custom_definitions([:prod_sku_number])
  end

end; end; end; end