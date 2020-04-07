require 'open_chain/custom_handler/fenix_nd_invoice_generator.rb'
require 'open_chain/custom_handler/vfitrack_custom_definition_support'
require 'open_chain/custom_handler/fenix_nd_invoice_generator'
require 'open_chain/custom_handler/under_armour/under_armour_business_logic'

module OpenChain; module CustomHandler; module UnderArmour; class UnderArmourFenixInvoiceGenerator < OpenChain::CustomHandler::FenixNdInvoiceGenerator
  include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport
  include OpenChain::CustomHandler::UnderArmour::UnderArmourBusinessLogic

  def generate_and_send_invoice shipment
    invoice = generate_invoice(shipment)
    generate_and_send(invoice)
  end

  def ftp_folder
    "to_ecs/fenix_invoices/UNDERARM"
  end

  def generate_invoice shipment
    # Really, we're just using the commercial invoice as a data transfer object feeding into
    # the fenix invoice generator...we're not actually saving these off as invoices.
    inv = CommercialInvoice.new
    inv.importer = shipment.importer
    inv.invoice_number = shipment.importer_reference
    inv.invoice_date = Time.zone.now.in_time_zone("America/New_York").to_date
    inv.total_quantity_uom = "CTN"
    inv.currency = "USD"

    inv.total_quantity = 0
    inv.gross_weight = BigDecimal.new("0")
    
    shipment.shipment_lines.each do |line|
      inv.total_quantity += line.carton_qty.presence || 0
      inv.gross_weight += line.gross_kgs.presence || 0
    end

    lines = rollup_shipment_lines shipment
    lines.each {|l| inv.commercial_invoice_lines << l }

    inv
  end

  private

    def rollup_shipment_lines shipment
      rollups = {}
      shipment.shipment_lines.each do |line|
        data = line_data(line)

        key = rollup_key(data)

        if rollups[key]
          rollups[key].quantity += data[:quantity]
        else
          cil = CommercialInvoiceLine.new
          cil.part_number = data[:style]
          cil.country_origin_code = data[:country_origin]
          cil.quantity = data[:quantity]
          cil.unit_price = data[:unit_price]
          cil.po_number = data[:order_number]
          cil.customer_reference = shipment.importer_reference

          tariff = cil.commercial_invoice_tariffs.build

          tariff.hts_code = data[:hts]
          tariff.tariff_description = data[:description]

          rollups[key] = cil
        end

      end

      rollups.values
    end

    def rollup_key data
      # None of these values should ever actually be blank...if they are, then use a random number to force the line to never get rolled up
      # The rater in CA will have to take care of the part manually based on the docs.
      [data[:order_number], data[:style], data[:country_origin], data[:unit_price], data[:hts]].map {|v| v.to_s.presence || Time.now.to_f.to_s }.join "*~*"
    end

    def line_data shipment_line
      # If the product on the shipment line is a prepack, we need to "explode" it out
      # and add a shipment line for every variant listed on the product...which we'll then 
      # roll up
      product = shipment_line.product
      variants = []
      prepack = false

      if product.custom_value(cdefs[:prod_prepack])
        prepack = true
        variants = shipment_line.product.variants.to_a
      else
        variants << shipment_line.variant
      end

      datum = {}
      datum[:country_origin] = shipment_line.custom_value(cdefs[:shpln_coo])
      order_line = shipment_line.order_lines.first
      datum[:order_number] = order_line.order.customer_order_number
      datum[:unit_price] = order_line.price_per_unit || BigDecimal("0")
      # For prepacks, this quantity is already an exploded quantity.  There's no need to loop through the
      # variants.
      datum[:quantity] = shipment_line.quantity.presence || BigDecimal("0")
      datum[:style] = product.custom_value(cdefs[:prod_part_number])

      # Under Armour has the potential to have an HTS value at the variant level...(due to their sizes
      # potentially having differing HTS numbers).
      # In this case, check the variant first and then check the actual CA tariff
      datum[:hts] = variants[0]&.custom_value(cdefs[:var_hts_code])
      description = nil
      classification = product.classifications.find {|c| c.country == ca}
      if classification
        # Tariff description can come from multiple potential spots...
        # First, look to the Classification's Customs Description, then fall back to the Product name field
        datum[:description] = classification.custom_value(cdefs[:class_customs_description])
        datum[:hts] = classification.tariff_records[0].try(:hts_1) if datum[:hts].blank?
      end

      datum[:description] = product.name if datum[:description].blank?

      datum
    end

    def ca 
      @ca ||= Country.where(iso_code: "CA").first
      raise "Missing Canada country" if @ca.nil?
      @ca
    end

    def cdefs
      @cd ||= self.class.prep_custom_definitions([:prod_part_number, :prod_prepack, :class_customs_description, :var_hts_code, :var_units_per_inner_pack, :shpln_coo])
    end

end; end; end; end