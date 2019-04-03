module OpenChain; module CustomHandler; module Pvh; module PvhEntryShipmentMatchingSupport

  def find_shipments transport_mode_code, master_bills_of_lading, house_bills_of_lading
    # Find all PVH shipments with the bill of lading numbers present on the shipment...since we'll need them all 
    # anyway to bill the entry.
    if @shipments.nil?
      # For air shipments, we're going to match on house bill, master bill for ocean.
      query_params = {importer_id: pvh_importer.id}
      if ocean_mode_entry?(transport_mode_code)
        query_params[:master_bill_of_lading] = master_bills_of_lading
      else
        query_params[:house_bill_of_lading] = house_bills_of_lading
      end

      @shipments = Shipment.where(query_params).to_a
    end

    @shipments
  end

  def ocean_mode_entry? transport_mode_code
    Entry.get_transport_mode_codes_us_ca("SEA").include?(transport_mode_code.to_i)
  end

  def find_shipment_line shipments, container_number, order_number, part_number, units
    units = 0 if units.nil?

    # Narrow down the shipment_lines to search over if we have a container number
    # We're not going to actually know the container number for each line for 
    # Canada (and probably a bunch of US invoice lines when lines are keyed).
    # In that case, we're just going to have to look through every line on the shipment
    # for something that matches to the po/part/unit count.
    shipment_lines = []
    if !container_number.blank?
      shipments.each do |s|
        container = s.containers.find {|c| c.container_number == container_number }
        shipment_lines.push(*container.shipment_lines) unless container.nil?
      end
    else
      shipments.each do |shipment|
        shipment_lines.push *shipment.shipment_lines
      end
    end

    translated_part_number = "PVH-#{part_number}"

    # Find all the shipment lines that might match this part / order number...there's potentially more than one
    order_matched_lines = shipment_lines.select do |line|
      # Skip any shipment lines we've already returned
      next if found_shipment_lines.include?(line)

      line.product&.unique_identifier == translated_part_number && line.order_line&.order&.customer_order_number == order_number
    end

    # If there's only one line on the shipment that matches, then just return it
    line = order_matched_lines[0] if order_matched_lines.length == 1

    if line.nil? && order_matched_lines.length > 0
      # At this point we need to try and use other factors to determine which shipment line to match to as there's multiple lines
      # that have the same part number / order number (which is possible if they're shipping multiple colors/sizes on different lines)

      # First try finding an exact match based on the # of units.  If there isn't an exact match, just use the shipment line that has the closest
      # unit count.
      unit_differences = []
      order_matched_lines.each do |line|
        difference = (line.quantity.abs - units.abs).abs
        unit_differences << {line: line, difference: difference}
      end

      line = unit_differences.sort {|a, b| a[:difference] <=> b[:difference] }.first[:line]
    end

    # we don't want to re-use the same shipment line, so keep track of which ones we've returned
    found_shipment_lines << line if line

    line
  end

  def find_shipment_container shipments, container_number
    container = nil
    shipments.each do |shipment|
      container = shipment.containers.find {|c| c.container_number == container_number }
      break unless container.nil?
    end

    container
  end

  def found_shipments
    @shipments.nil? ? [] : @shipments
  end

  def found_shipment_lines 
    @found_lines ||= Set.new
  end

  def pvh_importer
    @pvh ||= Company.where(system_code: "PVH").first
  end

end; end; end; end