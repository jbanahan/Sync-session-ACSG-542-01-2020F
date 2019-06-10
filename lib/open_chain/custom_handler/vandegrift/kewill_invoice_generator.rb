require 'open_chain/ftp_file_support'
require 'open_chain/custom_handler/vandegrift/kewill_shipment_xml_support'
require 'open_chain/custom_handler/vandegrift/kewill_commercial_invoice_generator'

# This class uses an Invoice object to send an invoice xml to Kewill.
module OpenChain; module CustomHandler; module Vandegrift; class KewillInvoiceGenerator
  include OpenChain::CustomHandler::Vandegrift::KewillShipmentXmlSupport

  def generate_and_send_invoice invoice, sync_record
    ci_entry = generate_invoice(invoice)

    generator.generate_and_send ci_entry, sync_record: sync_record
    nil
  end

  def generate_invoice invoice
    ci_entry = generate_entry_data(invoice)
    ci_invoice = generate_invoice_header(invoice)
    ci_entry.invoices << ci_invoice
    invoice.invoice_lines.each do |line|
      ci_invoice.invoice_lines << generate_invoice_line(line)
    end

    ci_entry
  end

  def generate_entry_data invoice
    ci_entry = CiLoadEntry.new
    ci_entry.customer = invoice.importer.try(:alliance_customer_number)
    ci_entry.file_number = invoice.invoice_number
    ci_entry.invoices = []
    ci_entry
  end

  def generate_invoice_header invoice
    ci_invoice = CiLoadInvoice.new 
    ci_invoice.invoice_number = invoice.invoice_number
    ci_invoice.invoice_date = invoice.invoice_date
    ci_invoice.currency = invoice.currency
    ci_invoice.invoice_lines = []
    ci_invoice
  end

  def generate_invoice_line invoice_line
    cil = CiLoadInvoiceLine.new
    cil.po_number = invoice_line.po_number
    cil.part_number = invoice_line.part_number
    cil.country_of_origin = invoice_line.country_origin.try(:iso_code)
    cil.country_of_export = invoice_line.country_export.try(:iso_code)
    cil.gross_weight = metric_weight(invoice_line.gross_weight, invoice_line.gross_weight_uom)
    cil.hts = invoice_line.hts_number
    cil.foreign_value = invoice_line.value_foreign
    cil.mid = invoice_line.mid
    cil.unit_price = invoice_line.unit_price
    cil.description = invoice_line.part_description
    cil.pieces = invoice_line.quantity
    cil.quantity_1 = invoice_line.customs_quantity
    cil.uom_1 = invoice_line.customs_quantity_uom
    cil.spi = invoice_line.spi
    cil.spi2 = invoice_line.spi2
    cil.department = invoice_line.department
    cil.cartons = invoice_line.cartons
    if invoice_line.value_foreign && invoice_line.middleman_charge
      cil.first_sale = invoice_line.value_foreign - invoice_line.middleman_charge
    end
    cil.related_parties = invoice_line.related_parties
    cil.container_number = invoice_line.container_number

    cil
  end


  def metric_weight amount, uom
    return nil unless amount

    weight = case uom.to_s.upcase
    when "LB", "LBS"
      (amount * BigDecimal("0.453592")).round(2)
    when "G" # Grams
      (amount / BigDecimal("1000")).round(2)
    else
      amount
    end

    # Since Kewill doesn't support decimal weights via the EDI feed, we're going to round anything
    # nonzero under 1 pound up to 1 pound.
    if weight.nonzero? && weight < 1
      weight = BigDecimal("1")
    end

    weight
   end

  def generator
    OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator.new
  end

end; end; end; end