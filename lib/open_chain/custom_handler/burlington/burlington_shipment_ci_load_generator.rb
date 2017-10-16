require 'open_chain/custom_handler/vfitrack_custom_definition_support'
require 'open_chain/custom_handler/vandegrift/kewill_commercial_invoice_generator'

module OpenChain; module CustomHandler; module Burlington; class BurlingtonShipmentCiLoadGenerator
  include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport

  def self.run_schedulable
    self.new.find_generate_and_send
  end

  def find_generate_and_send 
    # Look up any shipments that have last_exported_from_source times over 30 minutes ago that have not been sent.
    # This used to be 12 hours, but since we pull everything for the master bill each time we send, there's no real
    # point in waiting that long any longer.
    shipments = find_shipments(Time.zone.now - 30.minutes)
    grouped_shipments = Hash.new {|h, k| h[k] = [] }
    shipments.each {|s| grouped_shipments[s.master_bill_of_lading] << s }

    grouped_shipments.values.each do |shipments|
      begin
        all_shipments = generate_and_send(shipments)
        add_sync_records(all_shipments)
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
        # We may have some shipments that were already sent in here, don't update these...it'll help potential debugging scenarios
        # to be able to track the progress of the master bill.
        sr.update_attributes! sent_at: Time.zone.now, confirmed_at: (Time.zone.now + 1.minute) if sr.sent_at.nil?
      end
    end
  end

  def generate_and_send shipments
    # What we've received here is all the shipments that haven't already been synced...BUT...it's possible that Burlington sends us
    # updates to master bills that have already been synced.  Because of this, we're going to always include every shipment
    # that matches the master bill on the CI Load file we produce.
    synced_shipments = find_synced_shipments(shipments)

    all_shipments = shipments + synced_shipments

    # sort the shipments by the importer reference (which becomes the invoice number in the CI Load)
    all_shipments = all_shipments.sort {|a, b| a.importer_reference.to_s <=> b.importer_reference.to_s }
    
    entry_data = generate_entry_data all_shipments

    kewill_generator.generate_xls_to_google_drive "Burlington CI Load/#{Array.wrap(shipments).first.master_bill_of_lading}.xls", [entry_data]

    all_shipments
  end

  def find_synced_shipments shipments
    # NOTE: This also includes files that haven't been synced yet, but are less than 12 hours old...it's ok to sync these files too, since they will
    # be complete shipments and there's no sense waiting around for them to mature if we're sending other shipments for this master bill.
    Shipment.where(importer_id: shipments.first.importer_id, master_bill_of_lading: shipments.first.master_bill_of_lading).where("id NOT IN (?)", shipments.map {|s| s.id }).all
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
        hts_numbers = get_us_hts_numbers(line)
        first_hts = true
        hts_numbers.each do |tariff|
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

          # In the event a product has multiple US tariff numbers associated with it, several numeric values
          # are assigned to the first tariff only.  There is no per-tariff breakdown of these numbers.
          if first_hts
            cil.cartons += (line.carton_qty.presence || BigDecimal("0"))
            cil.gross_weight += (line.gross_kgs.presence || BigDecimal("0"))
            cil.pieces += (line.quantity || BigDecimal("0"))
            # Once the pieces have been updated, just recalculate the whole foreign value
            cil.foreign_value = (unit_price * cil.pieces)
          end
          first_hts = false
        end
      end
    end
    
    entry
  end

  def kewill_generator
    OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator.new
  end

  def get_us_hts_numbers shipment_line
    hts_numbers = []

    classification = shipment_line.product.classifications.find {|c| c.country == us }

    if classification
      hts_numbers = classification.tariff_records.select {|tariff| !tariff.hts_1.blank?}.map {|t| t.hts_1}
    end

    hts_numbers
  end

  def us
    @us ||= Country.where(iso_code: "US").first
    raise "US Country was not found" unless @us
    @us
  end

end; end; end; end