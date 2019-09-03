require 'open_chain/custom_handler/vandegrift/kewill_commercial_invoice_generator'
require 'open_chain/custom_handler/vfitrack_custom_definition_support'

module OpenChain; module CustomHandler; module Vandegrift; class KewillGenericShipmentCiLoadGenerator
  include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport

  def generate_and_send shipment
    entry_data = generate_entry_data shipment
    kewill_generator.generate_xls_to_google_drive drive_path(shipment), [entry_data]
    nil
  end

  def cdefs
    @cdefs ||= self.class.prep_custom_definitions([:prod_part_number, :shpln_coo, :shpln_invoice_number])
  end

  def generate_entry_data shipment
    entry = OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator::CiLoadEntry.new
    add_shipment_to_entry(entry, shipment)

    entry.invoices = []
    invoices = Hash.new do |h, k|
      invoice = OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator::CiLoadInvoice.new
      invoice.invoice_lines = []
      entry.invoices << invoice
      invoice.invoice_number = k

      h[k] = invoice
    end

    shipment.shipment_lines.each do |line|
      invoice_number = line.custom_value(cdefs[:shpln_invoice_number])
      invoice_number = "" if invoice_number.blank?

      invoice = invoices[invoice_number]
      add_shipment_to_invoice(invoice, shipment)
      add_shipment_line_to_invoice(invoice, line)

      cil = OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator::CiLoadInvoiceLine.new
      if line.product
        add_product_to_invoice_line(cil, line.product)
      end

      add_shipment_line_to_invoice_line cil, line

      if line.order_lines.length > 0
        add_order_line_to_invoice_line(cil, line.order_lines.first)
      end

      finalize_invoice_line(entry, invoice, cil)

      invoice.invoice_lines << cil
    end

    entry
  end

  def add_shipment_to_entry entry, shipment
    entry.customer = shipment.importer.kewill_customer_number
  end

  def add_shipment_to_invoice invoice, shipment
    # nothign by default, here mostly as an extension point / hook
  end

  def add_shipment_line_to_invoice invoice, shipment_line
    # nothign by default, here mostly as an extension point / hook
  end

  def add_product_to_invoice_line cil, product
    cil.part_number = product.custom_value(cdefs[:prod_part_number])
    cil.hts = product.hts_for_country("US").first
  end

  def add_shipment_line_to_invoice_line cil, shipment_line
    cil.cartons = shipment_line.carton_qty
    cil.gross_weight = shipment_line.gross_kgs
    cil.pieces = shipment_line.quantity
    cil.country_of_origin = shipment_line.custom_value(cdefs[:shpln_coo])
  end

  def add_order_line_to_invoice_line cil, ol
    order = ol.order
    cil.po_number = order.customer_order_number
    cil.country_of_origin = ol.country_of_origin if cil.country_of_origin.blank? && !ol.country_of_origin.blank?
    cil.foreign_value = ol.price_per_unit * cil.pieces

    factory = ol.order.factory
    cil.mid = factory.try(:mid)
  end

  def finalize_invoice_line entry, invoice, invoice_line
    invoice_line.buyer_customer_number = entry.customer
    invoice_line.seller_mid = invoice_line.mid
  end

  def kewill_generator
    OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator.new
  end

  def drive_path shipment
    # Name the file first based on the master bill, as that's the most likely thing operations should
    # have access to, then fall back to the importer reference if that's present, then fall back
    # to the shipment reference, as that is required on the shipment.
    filename = shipment.master_bill_of_lading
    filename = shipment.importer_reference if filename.blank?
    filename = shipment.reference if filename.blank?

    "#{shipment.importer.kewill_customer_number} CI Load/#{filename}.xls"
  end

end; end; end; end