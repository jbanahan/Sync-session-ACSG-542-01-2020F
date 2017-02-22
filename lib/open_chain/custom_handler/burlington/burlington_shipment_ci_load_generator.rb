require 'open_chain/custom_handler/vfitrack_custom_definition_support'
require 'open_chain/custom_handler/vandegrift/kewill_commercial_invoice_generator'

module OpenChain; module CustomHandler; module Burlington; class BurlingtonShipmentCiLoadGenerator
  include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport

  def self.run_schedulable
    self.new.find_generate_and_send
  end

  def find_generate_and_send 
    # Look up any shipments that have last_exported_from_source times over 12 hours ago that have not
    # been synce'd to Kewill.  Then group them together by master bill and send all the shipments with the
    # same master bill together into the same CI Load file.
    shipments = find_shipments(Time.zone.now - 12.hours)
    grouped_shipments = Hash.new {|h, k| h[k] = [] }
    shipments.each {|s| grouped_shipments[s.master_bill_of_lading] << s }

    grouped_shipments.values.each do |shipments|
      begin
        generate_and_send(shipments)
        add_sync_records(shipments)
      rescue => e
        e.log_me ["Master Bill: #{shipments.first.master_bill_of_lading}"]
      end
    end
  end

  def find_shipments prior_to
    Shipment.joins(:importer).
      where(companies: {system_code: "BURLI"}).
      where("last_exported_from_source < ? ", prior_to).
      joins("LEFT OUTER JOIN sync_records sr ON shipments.id = sr.syncable_id AND sr.syncable_type = 'Shipment' AND sr.trading_partner = 'CI Load'").
      where("sr.sent_at IS NULL").
      order("last_exported_from_source")
  end

  def add_sync_records shipments
    ActiveRecord::Base.transaction do 
      shipments.each do |s|
        sr = s.sync_records.first_or_initialize trading_partner: "CI Load"
        sr.update_attributes! sent_at: Time.zone.now, confirmed_at: (Time.zone.now + 1.minute)
      end
    end
  end

  def generate_and_send shipments
    entry_data = generate_entry_data shipments
    workbook = kewill_generator.generate_xls entry_data
    send_xls_to_google_drive workbook, "#{Array.wrap(shipments).first.master_bill_of_lading}.xls"
    nil
  end

  def cdefs
    @cdefs ||= self.class.prep_custom_definitions([:prod_part_number, :ord_type, :prod_department_code])
  end

  def generate_entry_data shipments
    shipments = Array.wrap(shipments)
    entry = OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator::CiLoadEntry.new
    entry.customer = "BURLI"
    entry.file_number = shipments.first.master_bill_of_lading
    entry.invoices = []

    invoices = {}

    shipments.each do |shipment|
      # There is no invoice number being mapped as we don't have that value in the 850/856 from Burlington
      # Just put each shipment under their own "invoice" on the spreadsheet, this at least gives
      # ops a reference number they can use to match against the shipment docs.
      invoice = invoices[shipment.importer_reference]
      if invoice.nil?
        invoice = OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator::CiLoadInvoice.new
        invoice.invoice_number = shipment.importer_reference
        invoice.invoice_lines = []
        entry.invoices << invoice
        invoices[shipment.importer_reference] = invoice
      end

      # Burlington's prepack lines should all reference the same product record (can just check that the product record
      # is the same).  We'll then roll up the lines based on PO # / Style#
      lines = {}

      shipment.shipment_lines.each do |line|
        
        # This should never happen, but it's potentially possible for someone to generate burlington 
        # data via the screen rather than via the 856 feed.  In which case, just skip those lines.
        next unless line.product && line.order_lines.length > 0

        style = line.product.custom_value(cdefs[:prod_part_number])
        order_line = line.order_lines.first
        po = order_line.order.customer_order_number
        unit_price = (order_line.price_per_unit || BigDecimal("0"))
        tariff = hts(line)
        key = "#{po}*~*#{style}*~*#{tariff}*~*#{unit_price}"
        cil = lines[key]
        if cil.nil?
          cil = OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator::CiLoadInvoiceLine.new
          cil.po_number = po
          cil.part_number = style
          cil.buyer_customer_number = "BURLI"
          cil.cartons = BigDecimal("0")
          cil.gross_weight = BigDecimal("0")
          cil.pieces = BigDecimal("0")
          cil.foreign_value = BigDecimal("0")
          cil.unit_price = unit_price
          cil.hts = tariff
          invoice.invoice_lines << cil
          lines[key] = cil
        end

        cil.cartons += (line.carton_qty.presence || BigDecimal("0"))
        cil.gross_weight += (line.gross_kgs.presence || BigDecimal("0"))
        cil.pieces += (line.quantity || BigDecimal("0"))
        # Once the pieces have been updated, just recalculate the whole foreign value
        cil.foreign_value = (unit_price * cil.pieces)
      end
    end
    
    entry
  end

  def kewill_generator
    OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator.new
  end

  def hts shipment_line
    hts = ""
    classification = shipment_line.product.classifications.find {|c| c.country == us }

    if classification
      hts = classification.tariff_records.first.try(:hts_1)
    end

    hts
  end

  def us
    @us ||= Country.where(iso_code: "US").first
    raise "US Country was not found" unless @us
    @us
  end

  def send_xls_to_google_drive wb, filename
    Tempfile.open([File.basename(filename, ".*"), File.extname(filename)]) do |t|
      t.binmode
      wb.write t
      t.flush
      t.rewind

      OpenChain::GoogleDrive.upload_file "integration@vandegriftinc.com", "Burlington CI Load/#{filename}", t 
    end
  end

end; end; end; end