module OpenChain; module CustomHandler; module Pvh; module PvhEntryShipmentMatchingSupport

  def find_shipments transport_mode_code, master_bills_of_lading, house_bills_of_lading, force_lookup:false
    # Find all PVH shipments with the bill of lading numbers present on the shipment...since we'll need them all
    # anyway to bill the entry.
    if @shipments.nil? || force_lookup

      # We're going to return shipments where master bills match or house bills match
      shipments_query = Shipment.where(importer_id: pvh_importer.id)
      if ocean_mode_entry? transport_mode_code
        shipments_query = shipments_query.where("mode LIKE ?", '%Ocean%')
      elsif air_mode_entry? transport_mode_code
        shipments_query = shipments_query.where("mode LIKE ?", '%Air%')
      elsif truck_mode_entry? transport_mode_code
        shipments_query = shipments_query.where("mode LIKE ?", '%Truck%')
      end

      master_bills_of_lading = Array.wrap(master_bills_of_lading).reject &:blank?
      house_bills_of_lading = Array.wrap(house_bills_of_lading).reject &:blank?

      if master_bills_of_lading.length > 0 && house_bills_of_lading.length > 0
        # In some movements (LCL's particularly), the house bill of lading on the entry show as the master on the shipment.
        shipments_query = shipments_query.where("master_bill_of_lading in (?) OR master_bill_of_lading IN (?) OR house_bill_of_lading IN (?)", master_bills_of_lading, house_bills_of_lading, house_bills_of_lading)
      elsif master_bills_of_lading.length > 0
        shipments_query = shipments_query.where(master_bill_of_lading: master_bills_of_lading)
      elsif house_bills_of_lading.length > 0
        shipments_query = shipments_query.where(house_bill_of_lading: house_bills_of_lading)
      else
        shipments_query = nil
      end

      @shipments = shipments_query.nil? ? [] : shipments_query.to_a
    end

    @shipments
  end

  def ocean_mode_entry? transport_mode_code
    Entry.get_transport_mode_codes_us_ca("SEA").include?(transport_mode_code.to_i)
  end

  def air_mode_entry? transport_mode_code
    Entry.get_transport_mode_codes_us_ca("AIR").include?(transport_mode_code.to_i)
  end

  def truck_mode_entry? transport_mode_code
    Entry.get_transport_mode_codes_us_ca("TRUCK").include?(transport_mode_code.to_i)
  end

  def ocean_lcl_entry? transport_mode_code, fcl_lcl
    ocean_mode_entry?(transport_mode_code) && (fcl_lcl.to_s =~ /LCL/i).present?
  end

  def find_shipment_line shipments, container_number, order_number, part_number, units, invoice_number: nil
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
    translated_order_number = "PVH-#{order_number}"

    # Find all the shipment lines that might match this part / order number...there's potentially more than one
    matched_lines = shipment_lines.select do |line|
      # Skip any shipment lines we've already returned
      next if found_shipment_lines.include?(line)

      line.product&.unique_identifier == translated_part_number && line.order_line&.order&.order_number == translated_order_number
    end

    if matched_lines.length == 0
      # If no order lines matched, see if we can match split tariffs
      matched_lines = find_potential_split_tariff_line(shipment_lines, order_number, translated_part_number)
    end

    if !invoice_number.blank? && matched_lines.length > 0
      # There's certain situations where the commercial invoice number is important to the matching process.  When the value is given
      # we should use it and ensure the shipment line matches on invoice number.
      matched_lines = matched_lines.find_all {|l| invoice_number == l.invoice_number.to_s.strip}
    end

    # If there's only one line on the shipment that matches, then just return it
    line = matched_lines[0] if matched_lines.length == 1

    if line.nil? && matched_lines.length > 0
      # At this point we need to try and use other factors to determine which shipment line to match to as there's multiple lines
      # that have the same part number / order number (which is possible if they're shipping multiple colors/sizes on different lines)

      # First try finding an exact match based on the # of units.  If there isn't an exact match, just use the shipment line that has the closest
      # unit count.
      unit_differences = []
      matched_lines.each do |line|
        difference = (line.quantity.abs - units.abs).abs
        unit_differences << {line: line, difference: difference}
      end

      line = unit_differences.sort {|a, b| a[:difference] <=> b[:difference] }.first[:line]
    end

    # we don't want to re-use the same shipment line, so keep track of which ones we've returned
    found_shipment_lines << line if line

    line
  end

  def find_potential_split_tariff_line shipment_lines, order_number, part_number
    translated_order_number = "PVH-#{order_number}"
    # For some cases where a commercial invoice line has to be split into two lines due to 
    # carrying two tariffs per 1 PO line, we're going to need to toss aside our rule of only using
    # a shipment line a single time.

    # From what we can tell, in these cases, the order line will have an HTS# of 9999999999.  Ergo, 
    # IF the the order line has an HTS of 9999999999, we will allow it to be utilized multiple times.
    shipment_lines.select do |line|
      line.order_line&.hts.to_s.strip == "9999999999" &&
          line.product&.unique_identifier == part_number &&
          line.order_line&.order&.order_number == translated_order_number
    end
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