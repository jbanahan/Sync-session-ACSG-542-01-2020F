require 'open_chain/custom_handler/vfitrack_custom_definition_support'
require 'open_chain/custom_handler/vandegrift/kewill_shipment_xml_support'

module OpenChain; module CustomHandler; module Vandegrift; class KewillShipmentEntryXmlGenerator
  include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport
  include OpenChain::CustomHandler::Vandegrift::KewillShipmentXmlSupport

  def generate_xml shipments
    data = generate_kewill_shipment_data(shipments)
    generate_entry_xml(data, add_entry_info: true)
  end

  def generate_kewill_shipment_data shipments
    shipments = Array.wrap(shipments)

    entry = generate_shipment_entry(shipments)
    generate_shipment_totals(shipments, entry)
    entry.bills_of_lading = generate_bills_of_lading(shipments)
    entry.dates = generate_dates(shipments)

    shipments.each do |shipment|
      shipment.containers.each do |container|
        entry.containers ||= []
        c = generate_kewill_shipment_container(shipment, container)
        entry.containers << c

        if c.description.blank?
          c.description = entry.goods_description
        end
      end
    end

    entry.invoices = generate_commercial_invoices(shipments)

    entry
  end

  # The idea here is that if you want to create custom variants of this you can easily extend this class
  # to build the entry data on a per implementation basis.
  protected

    def cdefs 
      @cdefs ||= self.class.prep_custom_definitions([:prod_part_number, :shp_entry_prepared_date])
    end

    def generate_shipment_entry shipments
      e = CiLoadEntry.new

      # Multiple shipments can potentially go on a single entry, when this happens, we're going to utilize the FIRST shipment
      # in the shipments parameter to pull the majority of the information for the entry (dates, vessel, voyage, etc...).  We'll utilize the other
      # shipments to pull master/house bills from
      shipment = shipments.first

      e.customer = shipment.importer.try(:alliance_customer_number)
      e.vessel = shipment.vessel
      e.voyage = shipment.voyage
      e.carrier = shipment.vessel_carrier_scac
      e.customs_ship_mode = customs_ship_mode(shipment)
      e.goods_description = goods_description(e, shipments)
      e.country_of_origin = shipment.country_origin.try(:iso_code)
      e.country_of_export = shipment.country_export.try(:iso_code)

      e
    end

    def generate_shipment_totals shipments, entry
      # Sum the weight and carton counts from all shipment lines
      weight = BigDecimal("0")
      cartons = 0

      shipments.each do |shipment|
        totals = shipment_lines_totals(shipment)
        weight += totals[:weight]
        cartons += totals[:cartons]
      end

      if weight > 0
        entry.weight_kg = weight
      end

      if cartons > 0
        entry.pieces = cartons
        entry.pieces_uom = "CTNS"
      end

    end

    def generate_bills_of_lading shipments
      master_house_combos = {}
      shipments.each do |s|
        master_bills = s.master_bill_of_lading.to_s.split("\n").map {|b| b.strip }
        master_bills.each do |master_bill|
          if !s.vessel_carrier_scac.blank? && !master_bill.starts_with?(s.vessel_carrier_scac)
            master_bill = "#{s.vessel_carrier_scac}#{master_bill}"
          end
          key = "#{master_bill.to_s.strip}~~~~~#{s.house_bill_of_lading.to_s.strip}"

          bill_of_lading = master_house_combos[key]
          if bill_of_lading.nil?
            bill_of_lading = CiLoadBillsOfLading.new
            bill_of_lading.master_bill = master_bill.to_s.strip
            bill_of_lading.house_bill = s.house_bill_of_lading.to_s.strip
            master_house_combos[key] = bill_of_lading
          end

          # If there's only a single master bill on the shipment, then we can get carton totals for the master bill in the 
          # same way we get the shipment totals.
          if master_bills.length == 1
            totals = shipment_lines_totals(s)
            if totals[:cartons].to_i > 0
              bill_of_lading.pieces ||= 0
              bill_of_lading.pieces += totals[:cartons]
              bill_of_lading.pieces_uom = "CTNS"
            end
          end
        end
      end

      master_house_combos.values.to_a
    end

    def shipment_lines_totals obj
      totals = {weight: BigDecimal("0"), cartons: 0}
      obj.shipment_lines.each do |line|
        totals[:cartons] += line.carton_qty.to_i
        totals[:weight] += line.gross_kgs if line.gross_kgs
      end

      totals
    end

    def generate_dates shipments
      # The way we're going to do this is by just using the first date type we see from the given shipments
      dates = {}
      est_export_date = nil
      shipments.each do |s|
        d = {est_arrival_date: s.est_arrival_port_date, export_date: s.departure_date}
        est_export_date = s.est_departure_date unless est_export_date

        d.each_pair do |k, v|
          dates[k] ||= v
        end
      end

      # If there's no actual departure date, set the est as the Export date
      dates[:export_date] = est_export_date if dates[:export_date].nil?

      dates.map { |k, v| CiLoadEntryDate.new k, v }
    end

    def generate_kewill_shipment_container shipment, container
      c = CiLoadContainer.new
      c.container_number = container.container_number
      c.seal_number = container.seal_number
      c.description = container.goods_description unless container.goods_description.blank?

      totals = shipment_lines_totals(container)

      c.weight_kg = totals[:weight] if totals[:weight] > 0

      if totals[:cartons] > 0
        c.pieces = totals[:cartons]
        c.pieces_uom = "CTNS"
      end

      size_data = calculate_container_size_and_type(container)
      c.size = size_data[:size]

      # High Cube should take priority over the actual type of container (reefer, etc)
      if size_data[:high_cube]
        c.container_type = "HQ"
      else
        c.container_type = size_data[:type]
      end

      c
    end

    def calculate_container_size_and_type container
      # Assume ISO codes and calculate size (20, 40, 45, etc) based on the size code
      # See https://en.wikipedia.org/wiki/ISO_6346#Size_and_Type_Codes for code explanations
      size = container.container_size.to_s.upcase

      # The first char of the container code should be its length
      container_size = case size[0]
        when "1"
          "10"
        when "2"
          "20"
        when "3"
          "30"
        when "4"
          "40"
        when "B"
          "24"
        when "C"
          "24.5"
        when "G"
          "41"
        when "H"
          "43"
        when "L"
          "45"
        when "M"
          "48"
        when "N"
          "49"
        else
          nil
        end

      # The second character is the container's height, we don't care about any heights EXCEPT
      # when the height is 9'6" (which is a High Cube) and is generally notated as such.
      # In Kewill, we send "HQ" as the container type to denote a High Cube container
      high_cube = ["5", "6", "E", "F"].include?(size[1])

      # The 3rd and 4th chars denote the the type of container (reefer, open top, etc)
      container_type = case size[2]
        when "R"
          "RE" # ISO Decription = Integral Reefer -> Kewill = Reefer
        when "P"
          "FR" # ISO Description = Flat or Bolster -> Kewill = Flat Rack
        when "U"
          "OT" # ISO Description = Open Top -> Kewill = Open Top
        else 
          nil
        end

      {size: container_size, high_cube: high_cube, type: container_type}
    end

    def customs_ship_mode shipment
      mode = shipment.mode.to_s
      if mode =~ /ocean/i
        return 11
      elsif mode =~ /air/i
        return 40
      else
        return nil
      end
    end

    def goods_description ci_load_entry, shipments
      # See if any of the shipments have a goods description, if so, use it..otherwise fall back to the default
      description = shipments.find {|s| !s.description_of_goods.blank? }.try(:description_of_goods)
      return description if !description.blank?

      return nil if ci_load_entry.customer.blank?

      DataCrossReference.where(key: ci_load_entry.customer).pluck(:value).first
    end

    def generate_commercial_invoices shipments
      # Group every line with an invoice number together and generate a commercial invoice record for them
      invoices = Hash.new do |h, k|
        h[k] = []
      end

      shipments.each do |shipment|
        shipment.shipment_lines.each do |line|
          next if line.invoice_number.blank?

          invoices[line.invoice_number.strip] << line
        end
      end

      invoices.values.map { |lines| generate_kewill_shipment_invoice lines }
    end

    def generate_kewill_shipment_invoice shipment_lines
      inv = CiLoadInvoice.new
      inv.invoice_lines = []
      inv.invoice_number = shipment_lines.first.invoice_number
      # In order to keep the date consistent across multiple potential resends, I'm going to use the shp_entry_prepared_date value (which
      # all shipments that are using the interface should have).  If that's blank, I'll fall back to the shipment create date.
      shipment = shipment_lines.first.shipment
      invoice_date = shipment.custom_value(cdefs[:shp_entry_prepared_date])
      if invoice_date.blank?
        invoice_date = shipment.created_at
      end

      inv.invoice_date = invoice_date.in_time_zone("America/New_York").to_date

      shipment_lines.each do |line|
        inv_line = generate_kewill_shipment_invoice_line line
        inv.invoice_lines << inv_line unless inv_line.nil?
      end

      inv
    end

    def generate_kewill_shipment_invoice_line shipment_line
      inv_line = CiLoadInvoiceLine.new

      inv_line.gross_weight = shipment_line.gross_kgs
      inv_line.pieces = shipment_line.quantity
      inv_line.container_number = shipment_line.container.try(:container_number)
      inv_line.cartons = shipment_line.carton_qty
      inv_line.mid = shipment_line.mid

      product = shipment_line.product
      if product
        inv_line.part_number = product.custom_value(cdefs[:prod_part_number])
        inv_line.description = product.name
        inv_line.hts = product.hts_for_country("US").first
      end      

      order_line = shipment_line.order_line
      if order_line
        inv_line.country_of_origin = order_line.country_of_origin
        inv_line.unit_price = order_line.price_per_unit
        inv_line.unit_price_uom = "PCS"
        inv_line.po_number = order_line.order.try(:customer_order_number)
        inv_line.hts = order_line.hts if inv_line.hts.blank?
      end

      if inv_line.country_of_origin.blank?
        inv_line.country_of_origin = shipment_line.shipment.country_origin.try(:iso_code)
      end

      inv_line.country_of_export = shipment_line.shipment.country_export.try(:iso_code)

      if inv_line.pieces && inv_line.unit_price
        inv_line.foreign_value = inv_line.pieces * inv_line.unit_price
      end

      inv_line
    end

end; end; end; end
