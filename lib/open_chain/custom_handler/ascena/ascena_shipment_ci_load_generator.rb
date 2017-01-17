require 'open_chain/custom_handler/vandegrift/kewill_commercial_invoice_generator'
require 'open_chain/custom_handler/vfitrack_custom_definition_support'

module OpenChain; module CustomHandler; module Ascena; class AscenaShipmentCiLoadGenerator
  include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport

  def generate_and_send shipment
    entry_data = generate_entry_data shipment
    wb = kewill_generator.generate_xls entry_data
    send_xls_to_google_drive wb, "#{Attachment.get_sanitized_filename(shipment.reference)}.xls"
    nil
  end

  def cdefs
    @cdefs ||= self.class.prep_custom_definitions([:prod_part_number, :ord_type, :prod_department_code])
  end

  def generate_entry_data shipment
    entry = OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator::CiLoadEntry.new
    entry.customer = "ASCE"

    # There is no invoice number being mapped...
    invoice  = OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator::CiLoadInvoice.new

    entry.invoices = [invoice]

    invoice.invoice_lines = []
    shipment.shipment_lines.each do |line|
      cil = OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator::CiLoadInvoiceLine.new
      if line.product
        cil.part_number = line.product.custom_value(cdefs[:prod_part_number])
        cil.department = line.product.custom_value(cdefs[:prod_department_code])
      end
      cil.cartons = line.carton_qty
      cil.gross_weight = line.gross_kgs
      cil.pieces = line.quantity
      cil.buyer_customer_number = "ASCE"

      if line.order_lines.length > 0
        ol = line.order_lines.first
        order = ol.order
        cil.po_number = order.customer_order_number

        # Only data from PO's that are NOT nonags types..nonags seems to be other systems
        # with dubious data in them.
        if order.custom_value(cdefs[:ord_type]).to_s.strip != "NONAGS"
          cil.country_of_origin = ol.country_of_origin

          if ol.price_per_unit.to_f != 0 && cil.pieces.to_f != 0
            cil.foreign_value = ol.price_per_unit * cil.pieces
          end
        end
      end

      invoice.invoice_lines << cil
    end

    entry
  end

  def kewill_generator
    OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator.new
  end

  def send_xls_to_google_drive wb, filename
    Tempfile.open([File.basename(filename, ".*"), File.extname(filename)]) do |t|
      t.binmode
      wb.write t
      t.flush
      t.rewind

      OpenChain::GoogleDrive.upload_file "integration@vandegriftinc.com", "Ascena CI Load/#{filename}", t 
    end
  end

end; end; end; end