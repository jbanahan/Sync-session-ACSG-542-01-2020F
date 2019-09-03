require 'open_chain/custom_handler/delivery_order_spreadsheet_generator'
require 'open_chain/custom_handler/vfitrack_custom_definition_support'

module OpenChain; module CustomHandler; module Pvh; class PvhDeliveryOrderSpreadsheetGenerator < OpenChain::CustomHandler::DeliveryOrderSpreadsheetGenerator
  include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport

  def initialize
    @cdefs = self.class.prep_custom_definitions [:ord_line_division, :ord_line_destination_code, :shpln_priority, :shpln_invoice_number]
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
    max_container_lines_per_page = 16
    max_line_length = 75

    destination_data.each_pair do |destination, data|
      header_base = clone_delivery_order(base_do)

      address = entry.importer.addresses.where(name: destination).first
      if address
        addr = ["PVH CORP", address.line_1, address.line_2, "#{address.city}, #{address.state} #{address.postal_code}", "#{address.phone_number.blank? ? "" : "PH: #{address.phone_number}"} #{address.fax_number.blank? ? "" : "FAX: #{address.fax_number}"}"]
        header_base.for_delivery_to = addr.reject {|v| v.blank? }
      else
        header_base.for_delivery_to = [destination]
      end

      # We need to make distinct delivery orders for every 4 sets of containers, since only that many fit on a single Delivery Order page.
      container_count = 0
      carton_count = 0
      bill_of_ladings = Set.new
      body = []
      body << "LCL" if lcl?(entry)

      container_weight = 0
      do_count = 0

      data[:containers].each do |container_data|
        container_count += 1

        # We can use a total of 16 container lines per tab, after that we need to 
        # start a new tab
        current_container_lines = (lcl?(entry) && body.length < 2) ? [] : [""]

        container_line = "#{container_data[:cartons].to_i} CTNS"
        container_line += " **#{container_data[:priority]}**" unless container_data[:priority].blank?
        container_line += " #{container_data[:container_number]}" unless container_data[:container_number].blank?
        container_line += " #{container_data[:container_type]}" unless container_data[:container_type].blank?
        container_line += " SEAL# #{container_data[:seal_number]}" unless container_data[:seal_number].blank?
        container_line += " #{to_lbs(container_data[:weight])} LBS" unless container_data[:weight].to_i == 0

        current_container_lines << container_line.strip

        division_line = ""
        container_data[:divisions].each do |division_data|
          division_line += " / " if division_line.length > 0
          division_line += "#{division_data[:division_number]} - #{division_data[:cartons]} CTNS"
        end

        if !division_line.blank?
          division_lines = split_line division_line.strip, max_line_length, / \/ /, "DIVISION ", ""
          current_container_lines.push *division_lines
        else
          # If we don't have any divisions, leave a blank line for them, user will have to manually add them
          current_container_lines << "DIVISION "
        end

        bols = container_data[:bols].join " "
        if !bols.blank?
          bol_lines = split_line(bols, max_line_length, / /, (container_data[:house_bills] ? "HOUSE BILL# " : "B/L# "), "")
          current_container_lines.push *bol_lines
        else
          # If we don't have any bols, leave a blank line for them, user will have to manually add them
          current_container_lines << (container_data[:house_bills] ? "HOUSE BILL# " : "B/L# ")
        end

        update_tab_info = lambda do
          carton_count += container_data[:cartons].to_i
          container_data[:bols].each {|b| bill_of_ladings << b }
          container_weight += container_data[:weight]
        end

        if (current_container_lines.length + body.length > max_container_lines_per_page) || data[:containers].size == container_count

          new_tab = lambda do |body_lines|
            do_count +=1

            del = clone_delivery_order header_base
            del.no_cartons = "#{carton_count} CTNS"

            if Array.wrap(data[:master_bills_of_lading]).length > 0
              del.bill_of_lading = (data[:master_bills_of_lading].size > 1) ? "MULTIPLE - SEE BELOW" : data[:master_bills_of_lading].first
            else
              del.bill_of_lading = (bill_of_ladings.size > 1) ? "MULTIPLE - SEE BELOW" : bill_of_ladings.first
            end
            
            del.body.push *body_lines
            del.tab_title = make_tab_title(destination, do_count)

            del.weight = "#{to_lbs(container_weight)} LBS"
            delivery_orders << del

            carton_count = 0
            bill_of_ladings.clear
            container_weight = 0
            body = []
          end

          if current_container_lines.length + body.length > max_container_lines_per_page
            new_tab.call body
          end

          update_tab_info.call
          body.push *current_container_lines

          if data[:containers].size == container_count
            new_tab.call body
          end
        else
          update_tab_info.call
          body.push *current_container_lines
        end
      end
    end

    delivery_orders
  end

  def clone_delivery_order del
    clone = del.dup
    # Make sure to clone the body array as well, since we're going to be modifiying it.
    clone.body = del.body.deep_dup
    clone
  end


  def base_delivery_order_data entry
    del = DeliveryOrderData.new

    del.date = Time.zone.now.in_time_zone("America/New_York").to_date
    del.vfi_reference = entry.broker_reference
    if entry.air?
      del.vessel_voyage = "#{entry.carrier_code} FLT: #{entry.voyage}"
      del.importing_carrier = entry.carrier_name
    else
      del.vessel_voyage = "#{entry.vessel} V#{entry.voyage}"
      del.importing_carrier = entry.carrier_code
    end
    
    del.freight_location = entry.location_of_goods_description
    del.port_of_origin = entry.lading_port.try(:name)
    
    del.arrival_date = entry.arrival_date ? entry.arrival_date.in_time_zone("America/New_York").to_date : nil
    del.instruction_provided_by = ["PVH CORP", "200 MADISON AVE", "NEW YORK, NY 10016-3903"]
    # Reference number has Country of Export prefaced on it.  For PVH, this will only ever be a single country.
    country_export = entry.export_country_codes.to_s.split("\n").first.to_s.strip
    del.body = ["PORT OF DISCHARGE: #{entry.unlading_port.try(:name)}", "REFERENCE: #{country_export}#{entry.broker_reference}", ""]

    del
  end

  def delivery_order_destination_data entry
    shipment_lines = get_shipment_lines(entry).includes(:shipment, :container)
    data = {}
    container_priorities = Hash.new {|h, k| h[k] = [] }
    shipment_lines.each do |line|
      order_line = line.piece_sets.first.try(:order_line)
      next unless order_line

      destination = order_line.custom_value(@cdefs[:ord_line_destination_code])
      next if destination.blank?

      dst_data = data[destination]
      if dst_data.nil?
        dst_data = {cartons: 0, containers: []}
        if lcl?(entry)
          dst_data[:master_bills_of_lading] = entry.split_master_bills_of_lading
        end
        data[destination] = dst_data
      end

      container_number = line.container.try(:container_number)
      next if container_number.blank?

      if !line.custom_value(@cdefs[:shpln_priority]).blank?
        container_priorities[container_number] << line.custom_value(@cdefs[:shpln_priority])
      end

      container_data = dst_data[:containers].find {|c| c[:container_number] == container_number}
      if container_data.nil?
        container = entry.containers.find {|c| container_number == c.container_number}
        container_data = {cartons: 0, priority: nil, container_number: container_number, container_type: entry_container_type(container), seal_number: container.try(:seal_number), weight: container.weight.to_i, divisions: [], bols: [], house_bills: lcl?(entry) }
        dst_data[:containers] << container_data
      end

      container_data[:bols] << line.shipment.master_bill_of_lading unless line.shipment.master_bill_of_lading.blank? || container_data[:bols].include?(line.shipment.master_bill_of_lading)

      division = order_line.custom_value(@cdefs[:ord_line_division])
      next if division.blank?

      division_data = container_data[:divisions].find {|d| d[:division_number] == division }
      if division_data.nil?
        division_data = {division_number: division, cartons: 0 }
        container_data[:divisions] << division_data
      end

      division_data[:cartons] += line.carton_qty
      dst_data[:cartons] += line.carton_qty
      container_data[:cartons] += line.carton_qty
    end

    # Backfill the container's priority based on the priority value associated with the first shipment line that actually had a non-blank priority
    data.each_pair do |destination, dst_data|
      dst_data[:containers].each do |cnt_data|
        cnt_data[:priority] = container_priorities[cnt_data[:container_number]].first
      end
    end

    # If we don't have any data at all that matched to shipments from the PVH workflow spreadsheet, then we'll try our best 
    # to at least just populate the data that we can from the entry onto the delivery order
    if data.length == 0
      # Yes, technically anything that's not an ocean mode we're considering air, which is fine for this case
      air_shipment = !entry.transport_mode_code.blank? && !entry.ocean?
      lcl_shipment = lcl?(entry)

      dst_data = {containers: []}

      if air_shipment || lcl_shipment
        dst_data[:master_bills_of_lading] = entry.split_master_bills_of_lading.map {|bol| air_shipment ? "MAWB: #{bol}" : bol}
      end

      data['PVH'] = dst_data

      entry.containers.each do |c|
        container_data = {cartons: c.quantity.to_i, priority: nil, container_number: c.container_number, container_type: entry_container_type(c), seal_number: c.seal_number, weight: c.weight.to_i, divisions: [], bols: entry.split_master_bills_of_lading, house_bills: false }
        dst_data[:containers] << container_data

        if lcl_shipment || air_shipment
          container_data[:bols] = entry.split_house_bills_of_lading
          container_data[:house_bills] = true
        end
      end
      
      # If there are no containers on here, create a dummy container record (this will be likely for air shipments)
      if entry.containers.length == 0
        container_data = {cartons: entry.total_packages.to_i, priority: nil, container_number: "", container_type: "", seal_number: "", weight: entry.gross_weight.to_i, divisions: [], bols: entry.split_master_bills_of_lading, house_bills: false}
        dst_data[:containers] << container_data 

        if lcl_shipment || air_shipment
          container_data[:bols] = entry.split_house_bills_of_lading
          container_data[:house_bills] = true
        end
        
        
      end
    end

    data
  end

  def lcl? entry
    entry.fcl_lcl.to_s =~ /LCL/i
  end

  def get_shipment_lines entry
    containers = entry.containers.map {|c| c.container_number.blank? ? nil : c.container_number.strip }.uniq
    # For air shipments, the master bill on the shipment matches to the entry's house bill (we don't know in the shipment parser if the 
    # the shipment is air or ocean, so we just put the bol in master bill)
    bills = entry.master_bills_of_lading.to_s.split(/\s*\n\s*/) + entry.house_bills_of_lading.to_s.split(/\s*\n\s*/)

    shipment_lines = ShipmentLine.select("DISTINCT shipment_lines.*").
                        joins("INNER JOIN shipments ON shipments.id = shipment_lines.shipment_id").
                        joins("INNER JOIN containers ON containers.id = shipment_lines.container_id").
                        joins("INNER JOIN companies on companies.id = shipments.importer_id").
                        where("companies.id = ?", Company.with_customs_management_number('PVHWSHT').first.id).
                        where("containers.container_number IN (?)", containers).
                        where("shipments.master_bill_of_lading IN (?)", bills)

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

  def to_lbs weight_kgs
    (BigDecimal(weight_kgs) * BigDecimal("2.20462")).round.to_i
  end

  # This method splits lines so that their at most max_line_length long.
  # If they are over that lenght, then it finds the rightmost occurrence of 
  # the supplied regex as the cutoff point for the string.
  # 
  # Returns an array of the split lines.
  def split_line starting_line, max_line_length, separator_regex, prefix, continued_prefix
    next_line = starting_line
    lines = []

    begin
      line_prefix = lines.length == 0 ? prefix : continued_prefix

      if (next_line.length + line_prefix.length) > max_line_length
        current_line = next_line[0, max_line_length - line_prefix.length].strip
        next_line = next_line[current_line.length..-1]

        # Find the nearest space prior to current_lines end, that's where we want to chop off at (or if next_line starts
        # with the separator, then we by chance chopped at the exact correct spot)
        if next_line[separator_regex] == 0
          lines << "#{line_prefix}#{current_line.strip}"
        else
          match_data = last_match_data(current_line, separator_regex)
          if match_data.nil?
            # If the separator is not found, just use the whole line as is
            lines << "#{line_prefix}#{current_line}"
          else
            lines << "#{line_prefix}#{match_data.pre_match.strip}"
            next_line = (match_data.post_match + next_line).strip
          end
        end
      else
        lines << "#{line_prefix}#{next_line.strip}"
        next_line = nil
      end
    end while !next_line.blank?

    lines
  end

  def last_match_data string, regex
    match = nil
    current_match = nil
    index = 0
    begin
      current_match = string.match regex, index
      if current_match 
        match = current_match
        index = match.pre_match.length + match.to_s.length
      end
    end while !current_match.nil?

    match
  end

  def make_tab_title title, index
    # Excel limits tab lengths to 31 chars max, so we can end up in a situation where the drop ship
    # name is really long and excel trims to 31 chars.  However, if we have multiple tabs to make
    # for the drop ship location, then we end up having the index cut off from the tab and try
    # and make multiple sheets in excel with the same tab name...which excel (xlserver) doesn't like and barfs.
    max_length = 30

    tab_title = (title.length > max_length) ? title[0, max_length] : title
    if index > 1
      suffix = "(#{index})"
      new_title = tab_title + " " + suffix
      if new_title.length > max_length
        new_title = tab_title[0, ((max_length - 1) - suffix.length)] + " " + suffix
      end

      tab_title = new_title
    end

    tab_title
  end

end; end; end; end;
