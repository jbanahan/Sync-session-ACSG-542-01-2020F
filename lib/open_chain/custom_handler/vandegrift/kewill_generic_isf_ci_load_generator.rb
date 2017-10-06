require 'open_chain/custom_handler/vandegrift/kewill_commercial_invoice_generator'
require 'open_chain/custom_handler/vfitrack_custom_definition_support'

module OpenChain; module CustomHandler; module Vandegrift; class KewillGenericIsfCiLoadGenerator
  include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport

  def generate_and_send isf
    entry_data = generate_entry_data isf
    kewill_generator.generate_xls_to_google_drive drive_path(isf), [entry_data]
    nil
  end

  def generate_entry_data isf
    create_config(isf.broker_customer_number)

    entry = OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator::CiLoadEntry.new
    add_isf_to_entry(entry, isf)

    entry.invoices = []
    invoices = Hash.new do |h, k|
      invoice = OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator::CiLoadInvoice.new
      invoice.invoice_lines = []
      entry.invoices << invoice
      invoice.invoice_number = k

      h[k] = invoice
    end
    importer = supply_chain_importer(isf)
    linked_shipments = find_linked_shipments(isf, importer)

    isf.security_filing_lines.each do |line|
      shipment_lines = find_shipment_lines(linked_shipments, line)

      invoice_number = isf_invoice_number(shipment_lines, line)
      invoice_number = "" if invoice_number.blank?

      invoice = invoices[invoice_number]

      add_isf_line_to_invoice(invoice, line)

      cil = OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator::CiLoadInvoiceLine.new
      add_isf_line_to_invoice_line cil, line

      if shipment_lines.length > 0
        # Even if there's technically multiple order lines referenced by teh shipment lines, they should
        # all have the same information pertinent to the shipment.  The lines should basically jsut be different
        # sizes or something along those lines.
        order_line = find_order_line(cil, shipment_lines)

        if order_line
          product = order_line.try(:product)
          add_product_to_invoice_line(cil, product) if product

          add_order_line_to_invoice_line(cil, order_line)
        end
        
        add_shipment_lines_to_invoice_line(cil, shipment_lines) 
      end

      finalize_invoice_line(entry, invoice, cil)

      invoice.invoice_lines << cil
    end

    entry
  end

  def drive_path isf
    # A Master bill or house bill is absolutely required on an ISF so it'll never be missing
    filename = isf.master_bill_of_lading.presence || isf.house_bills_of_lading
    "#{isf.broker_customer_number} CI Load/#{Attachment.get_sanitized_filename(filename)}.xls"
  end

  protected

    def supply_chain_importer isf
      isf.importer
    end

    def find_linked_shipments isf, supply_chain_importer
      return [] unless output_config[:use_shipment] == true

      shipments = []
      if !isf.master_bill_of_lading.blank?
        shipments.push *Shipment.where(importer_id: supply_chain_importer.id, master_bill_of_lading: isf.master_bill_of_lading).all
      end

      if !isf.house_bills_of_lading.blank?
        rel = Shipment.where(importer_id: supply_chain_importer.id, house_bill_of_lading: isf.house_bills_of_lading)
        if shipments.length > 0
          rel = rel.where("shipments.id NOT IN (?)", shipments.map(&:id))
        end
        shipments.push rel.all
      end

      shipments
    end

    def find_shipment_lines shipments, isf_line
      return [] if isf_line.po_number.blank? || isf_line.part_number.blank? || shipments.length == 0

      # We COULD walk the active record heirarch to find which shipment line to use, but that's going to end up loading a ton
      # of extra objects and running several queries..pre-emptively optimizing this.
      ShipmentLine.
        joins("INNER JOIN products on shipment_lines.product_id = products.id").
        joins("INNER JOIN custom_values on products.id = custom_values.customizable_id and custom_values.customizable_type = 'Product' and custom_values.custom_definition_id = #{cdefs[:prod_part_number].id}").
        joins("INNER JOIN piece_sets on shipment_lines.id = piece_sets.shipment_line_id").
        joins("INNER JOIN order_lines on piece_sets.order_line_id = order_lines.id").
        joins("INNER JOIN orders on orders.id = order_lines.order_id").
        where("shipment_lines.shipment_id IN (?) AND custom_values.string_value = ? AND orders.customer_order_number = ?", shipments.map(&:id), isf_line.part_number, isf_line.po_number).
        all
    end

    def add_isf_to_entry entry, isf
      entry.customer = isf.broker_customer_number
    end

    def add_isf_to_invoice invoice, isf
      # nothign by default, here mostly as an extension point / hook
    end

    def add_isf_line_to_invoice invoice, isf_line
      # nothign by default, here mostly as an extension point / hook
    end

    def isf_invoice_number shipment_lines, isf_line
      invoice = isf_line.commercial_invoice_number
      if invoice.blank?
        # See if any of the shipment lines have an invoice # on them
        invoice = shipment_lines.map {|l| l.custom_value(cdefs[:shpln_invoice_number]).presence }.compact.first
      end

      invoice.blank? ? "" : invoice
    end

    def add_isf_line_to_invoice_line cil, isf_line
      cil.part_number = isf_line.part_number
      cil.po_number = isf_line.po_number
      cil.mid = isf_line.mid
      cil.country_of_origin = isf_line.country_of_origin_code
      cil.hts = isf_line.hts_code
      # ISF Quantity is intentionally left out here...I don't think ops can even fill the value in (there's no a single ISF
      # in the system that has a nonzero value)
    end

    def add_product_to_invoice_line cil, product
      # Check the product's US HTS if we don't already have a full 10 digit hts on the cil line
      if output_config[:use_product_hts] == true
        hts = cil.hts.to_s
        if hts.length < 10
          prod_hts = product.hts_for_country("US").first

          if prod_hts.starts_with? hts
            cil.hts = prod_hts
          end
        end
      end
    end

    def add_shipment_lines_to_invoice_line cil, shipment_lines
      config = output_config

      cartons = BigDecimal("0")
      gross_weight = BigDecimal("0")
      pieces = BigDecimal("0")
      coo = nil

      shipment_lines.each do |line|
        cartons += line.carton_qty.presence || 0
        gross_weight += line.gross_kgs.presence || 0
        pieces += line.quantity.presence || 0

        coo = line.custom_value(cdefs[:shpln_coo]) if cil.country_of_origin.blank?
      end

      cil.cartons = cartons if config[:use_shipment_cartons] == true && cartons.nonzero?
      cil.gross_weight = gross_weight if config[:use_shipment_gross_weight] == true && gross_weight.nonzero?
      cil.pieces = pieces if config[:use_shipment_pieces] == true && pieces.nonzero?
      cil.country_of_origin = coo if cil.country_of_origin.blank? && !coo.blank?
    end

    def find_order_line cil, shipment_lines
      return nil if shipment_lines.length == 0

      # Just return the first order line we have found
      shipment_lines.each do |line|
        ol = line.order_lines.first

        return ol unless ol.nil?
      end

      nil
    end

    def add_order_line_to_invoice_line cil, ol
      if cil.country_of_origin.blank?
        cil.country_of_origin = ol.country_of_origin unless ol.country_of_origin.blank?  
      end

      if cil.mid.blank?
        cil.mid = ol.order.factory.try(:mid)
      end

      cil.unit_price = ol.price_per_unit
    end

    def finalize_invoice_line entry, invoice, invoice_line
      invoice_line.buyer_customer_number = entry.customer
      invoice_line.seller_mid = invoice_line.mid
      if invoice_line.unit_price && invoice_line.pieces && !invoice_line.foreign_value
        invoice_line.foreign_value = invoice_line.unit_price * invoice_line.pieces
      end
    end

    def kewill_generator
      OpenChain::CustomHandler::Vandegrift::KewillCommercialInvoiceGenerator.new
    end

    def cdefs
      @cds ||= begin
        self.class.prep_custom_definitions([:prod_part_number, :shpln_coo, :shpln_invoice_number])
      end

      @cds
    end

    def create_config customer_number
      # Even though we collect some pieces of data from shipments/orders we may not be able to use them
      # (for instance if the piece count is inaccurate).  We'll use a json config to determine what can be output.
      @config ||= begin 
        json = KeyJsonItem.isf_config(customer_number).first
        default_config.merge(json ? json.data.with_indifferent_access : {})
      end

      @config
    end

    def output_config
      raise "Output configuration cannot be accessed until it has been created.  See create_config method." unless defined?(:@config)

      @config
    end

    def default_config
      {
        use_shipment: true,
        use_shipment_pieces: true,
        use_shipment_gross_weight: true,
        use_shipment_cartons: true,
        use_product_hts: true
      }.with_indifferent_access
    end

end; end; end; end