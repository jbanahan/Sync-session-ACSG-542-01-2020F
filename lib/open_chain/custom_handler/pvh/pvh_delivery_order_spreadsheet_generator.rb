require 'open_chain/custom_handler/delivery_order_spreadsheet_generator'
require 'open_chain/custom_handler/vfitrack_custom_definition_support'

module OpenChain; module CustomHandler; module Pvh; class PvhDeliveryOrderSpreadsheetGenerator < OpenChain::CustomHandler::DeliveryOrderSpreadsheetGenerator
  include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport

  def initialize
    @cdefs = self.class.prep_custom_definitions [:ord_division, :ord_line_destination_code, :shp_priority, :shpln_invoice_number]
  end

  def generate_delivery_order_data entry
    base = base_delivery_order_data entry

    # We need to generate a delivery order for every destination present on the shipment
    # Destinations are found as custom fields at the PO Line level.
    destination_data = delivery_order_destination_data(entry)
    build_delivery_orders base, destination_data, entry
  end

  def build_delivery_orders base_do, destination_data, entry
    delivery_orders = []
    
    destination_data.each_pair do |destination, data|
      del = base_do.dup
      del.tab_title = destination

      bill_of_ladings = Set.new

      # Make sure to clone the body array as well, since we're going to be modifiying it.
      del.body = base_do.body.deep_dup

      address = entry.importer.addresses.where(name: destination).first
      if address
        addr = ["PVH CORP", address.line_1, address.line_2, "#{address.city}, #{address.state} #{address.postal_code}", "#{address.phone_number.blank? ? "" : "PH: #{address.phone_number}"} #{address.fax_number.blank? ? "" : "FAX: #{address.fax_number}"}"]
        del.for_delivery_to = addr.reject {|v| v.blank? }
      else
        del.for_delivery_to = [destination]
      end

      del.no_cartons = "#{data[:cartons]} CTNS"

      data[:containers].each do |container_data|
        container_line = "#{container_data[:cartons]} CTNS"
        container_line += " **#{container_data[:priority]}**" unless container_data[:priority].blank?
        container_line += " #{container_data[:container_number]} #{container_data[:container_type]}"
        container_line += " SEAL# #{container_data[:seal_number]}"

        del.body << ""
        del.body << container_line

        division_line = ""
        container_data[:divisions].each do |division_data|
          division_line += "#{division_data[:division_number]} - #{division_data[:cartons]} CTNS "
        end

        if !division_line.blank?
          del.body << "DIVISION #{division_line}".strip
        end

        container_data[:bols].each {|b| bill_of_ladings << b }
        bols = container_data[:bols].join " "
        del.body << "B/L# #{bols}" unless bols.blank?
      end

      # Set the BOL indicator 
      del.bill_of_lading = (bill_of_ladings.size > 1) ? "MULTIPLE - SEE BELOW" : bill_of_ladings.first
      delivery_orders << del
    end

    delivery_orders
  end


  def base_delivery_order_data entry
    del = DeliveryOrderData.new

    del.date = Time.zone.now.in_time_zone("America/New_York").to_date
    del.vfi_reference = entry.broker_reference
    del.vessel_voyage = "#{entry.vessel} V#{entry.voyage}"
    del.freight_location = entry.location_of_goods_description
    del.port_of_origin = entry.lading_port.try(:name)
    del.importing_carrier = entry.carrier_code
    del.arrival_date = entry.arrival_date ? entry.arrival_date.in_time_zone("America/New_York").to_date : nil
    del.instruction_provided_by = ["PVH CORP", "200 MADISON AVE", "NEW YORK, NY 10016-3903"]
    # Reference number has Country of Export prefaced on it.  For PVH, this will only ever be a single country.
    country_export = entry.export_country_codes.split("\n").first.strip
    del.body = ["PORT OF DISCHARGE: #{entry.unlading_port.try(:name)}", "REFERENCE: #{country_export}#{entry.broker_reference}", ""]

    del
  end

  def delivery_order_destination_data entry
    shipment_lines = get_shipment_lines(entry).includes(:shipment, :container)
    data = {}
    shipment_lines.each do |line|
      order_line = line.piece_sets.first.try(:order_line)
      next unless order_line

      destination = order_line.custom_value(@cdefs[:ord_line_destination_code])
      next if destination.blank?

      dst_data = data[destination]
      if dst_data.nil?
        dst_data = {cartons: 0, containers: []}
        data[destination] = dst_data
      end

      dst_data[:cartons] += line.carton_qty

      container_number = line.container.try(:container_number)
      next if container_number.blank?

      container_data = dst_data[:containers].find {|c| c[:container_number] == container_number}
      if container_data.nil?
        container = entry.containers.find {|c| container_number == c.container_number}
        container_data = {cartons: 0, priority: line.shipment.custom_value(@cdefs[:shp_priority]), container_number: container_number, container_type: entry_container_type(container), seal_number: container.try(:seal_number), divisions: [], bols: [] }
        dst_data[:containers] << container_data
      end

      container_data[:cartons] += line.carton_qty
      container_data[:bols] << line.shipment.master_bill_of_lading unless line.shipment.master_bill_of_lading.blank? || container_data[:bols].include?(line.shipment.master_bill_of_lading)


      division = order_line.order.custom_value(@cdefs[:ord_division])
      next if division.blank?

      division_data = container_data[:divisions].find {|d| d[:division_number] == division }
      if division_data.nil?
        division_data = {division_number: division, cartons: 0 }
        container_data[:divisions] << division_data
      end

      division_data[:cartons] += line.carton_qty
      
    end

    data
  end 

  def get_shipment_lines entry
    invoice_numbers = entry.commercial_invoices.map {|inv| inv.invoice_number.blank? ? nil : inv.invoice_number.strip }.uniq
    containers = entry.containers.map {|c| c.container_number.blank? ? nil : c.container_number.strip }.uniq
    master_bills = entry.master_bills_of_lading.split(/\s*\n\s*/)

    shipment_lines = ShipmentLine.select("DISTINCT shipment_lines.*").
                        joins("INNER JOIN shipments ON shipments.id = shipment_lines.shipment_id").
                        joins("INNER JOIN containers ON containers.id = shipment_lines.container_id").
                        joins("INNER JOIN companies on companies.id = shipments.importer_id").
                        joins("INNER JOIN custom_values on custom_values.customizable_id = shipment_lines.id AND custom_values.customizable_type = 'ShipmentLine' and custom_values.custom_definition_id = " + @cdefs[:shpln_invoice_number].id.to_s).
                        where("companies.alliance_customer_number = ? ", entry.customer_number).
                        where("containers.container_number IN (?)", containers).
                        where("custom_values.string_value IN (?)", invoice_numbers).
                        where("shipments.master_bill_of_lading IN (?)", master_bills)

    shipment_lines
  end

  def entry_container_type container
    size = container.try(:container_size)
    desc = container.try(:size_description)

    if size =~ /^\d+$/
      size += "'"
    end

    # Change the descriptions to be abbreviated variants...Dry Van => "" High Cube => HC
    if desc.try(:upcase) == "DRY VAN"
      desc = ""
    elsif desc.try(:upcase) == "HIGH CUBE"
      desc = "HC"
    end

    desc.blank? ? size : (size + desc)
  end


end; end; end; end;