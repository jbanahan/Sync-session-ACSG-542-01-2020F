require 'rex12'
require 'open_chain/integration_client_parser'
require 'open_chain/edi_parser_support'
require 'open_chain/custom_handler/vfitrack_custom_definition_support'

module OpenChain; module CustomHandler; module Burlington; class Burlington856Parser
  extend OpenChain::IntegrationClientParser
  include OpenChain::EdiParserSupport
  include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport
  include OpenChain::DelayedJobExtensions

  def self.integration_folder
    "/home/ubuntu/ftproot/chainroot/www-vfitrack-net/_burlington_856"
  end

  def process_transaction user, segments, last_file_bucket:, last_file_path:
    # Use the BSN03-04 value as the send date and our indicator of whether the shipment data is outdated or not in reprocessing scenarios
    bsn = find_segment(segments, "BSN")
    shipment_number = value(bsn, 2)
    shipment_date = parse_date(Array.wrap(value(bsn, (3..4))).join)
    s = nil
    find_or_create_shipment(shipment_number, shipment_date, last_file_bucket, last_file_path) do |shipment|
      # destroy all shipment lines / containers...technically we could re-use containers
      # but that would save so little processing time that it's just easier to rebuild them
      # all from scratch each time we get an 856.
      shipment.containers.destroy_all
      shipment.shipment_lines.destroy_all

      hl_loops = extract_hl_loops(segments, stop_segments: "CTT")

      # The outer most loop is always going to be the shipment
      process_shipment_header shipment, hl_loops[:segments]

      # The BSN05 value indicates the HL structure of the 856, for Burlington it has 3 potential values.
      # 2 of which we should never receive.
      # 0001: Shipment, Order, Packaging (.ie carton), Item (.ie style)
      # 0002: Shipment, Order, Item, Packaging
      # 0004: Shipment, Order, Item
      loop_structure = value(bsn, 5)
      case loop_structure
      when "0001"
        process_order_pack_item_loops(shipment, hl_loops)
      when "0002"
        process_order_item_pack_loops(shipment, hl_loops)
      else
        raise EdiStructuralError, "Unexpected BSN05 Heirarchical Structure Code value received: '#{loop_structure}'."
      end

      calculate_shipment_totals shipment

      shipment.save!
      shipment.create_snapshot user, nil, last_file_path
      s = shipment
    end

    s
  end

  def process_shipment_header shipment, segments
    find_segments(segments, "TD5") do |td5|
      # Since there's the potential for multiple TD5's
      scac = value(td5, 3)
      shipment.vessel_carrier_scac = scac unless scac.blank?
      mode = value(td5, 4)
      shipment.mode = ship_mode(mode) unless mode.blank?

      port_code = value(td5, 8)
      unless port_code.blank?
        p = port(port_code)
        case value(td5, 7)
        when "KL"
          shipment.lading_port = p
        when "PE"
          shipment.entry_port = p
        when "PB"
          shipment.destination_port = p
        when "PA"
          shipment.unlading_port = p
        end
      end
    end

    find_segment(segments, "TD3") do |td3|
      container_number = value(td3, (2..3)).join

      c = shipment.containers.find {|c| c.container_number == container_number }
      if c.nil?
        c = shipment.containers.build container_number: container_number
      end

      c.seal_number = value(td3, 9)
    end

    shipment.master_bill_of_lading = find_ref_value(segments, "BM")
    shipment.house_bill_of_lading = find_ref_value(segments, "CN")
    
    find_segments(segments, "DTM") do |dtm|
      datetime = parse_date(Array.wrap(value(dtm, (2..3))).join)
      next unless datetime

      case value(dtm, 1)
      when "011"
        shipment.departure_date = datetime.to_date
      when "017"
        shipment.est_delivery_date = datetime.to_date
      when "AA1"
        shipment.est_arrival_port_date = datetime.to_date
      when "AA2"
        shipment.est_inland_port_date = datetime.to_date
      end
    end

    shipment
  end

  def calculate_shipment_totals shipment
    shipment.number_of_packages_uom = "CTN"
    shipment.number_of_packages = 0
    shipment.gross_weight = BigDecimal("0")

    shipment.shipment_lines.each do |line|
      shipment.number_of_packages += line.carton_qty unless line.carton_qty.nil?
      shipment.gross_weight += line.gross_kgs unless line.carton_qty.nil?
    end
  end

  def process_order_pack_item_loops shipment, hl_loops
    # In the 856, every single carton on the shipment is sent as individual Pack and Item 
    # loops.  We're obviously not going to create a distinct shipment line for each carton
    # so we'll roll everthing up to order/styles (the style on the 856 is actually the buyer style
    # on the order lines).
    po_weights = {}
    po = {}
    hl_loops[:hl_children].each do |po_loop|
      po_number = find_element_value(po_loop[:segments], "PRF01")
      td1 = find_segment(po_loop[:segments], "TD1")

      # Burlington doesn't send multiple lines on PO's...every PO "line" in their system is cut as 
      # a distinct 850 - the po # is 7 digits and the last 2 digits of the 9 digit number we receive
      # is the virtual line number.  What that means is that we'll never have multiple non-prepack items that
      # below to the same PO.  For the prepack items, we'll need to prorate this gross weight
      # based on the total item counts of each prepack.
      po_weights[po_number] = calculate_weight(td1)

      # This hash is just a style => {quantity:, cartons:} linkage
      po_data = po[po_number]
      if po_data.nil?
        po_data = Hash.new {|h, k| h[k] = {quantity: BigDecimal("0"), cartons: 0} }
        po[po_number] = po_data
      end

      po_loop[:hl_children].each do |pack_loop|
        pack_loop[:hl_children].each do |item_loop|
          uom = find_element_value(item_loop[:segments], "SN103")

          if uom == "AS"
            # Each prepack is a unique style that we'll add as a line on the shipment (since we explode 
            # prepacks on the order)
            # We don't have to do what we did with the 850 and multiply the prepack quantity by the 
            # Line's quantity.  In this case, the SN102 value is just the sum of the prepack quantities inside the carton.
            #
            # The only real catch is that since all of the prepacks are in the same carton we can't add a distinct
            # carton for every line..We'll work around that by just putting the carton amount on the first prepack
            # line and leaving the others with 0 cartons
            added_carton = false
            subline_count = 0
            find_segments(item_loop[:segments], "SLN") do |prepack|
              subline_count +=1
              style = find_style(prepack)
              quantity = BigDecimal(value(prepack, 4))
              po_data[style][:quantity] += quantity
              unless added_carton
                po_data[style][:cartons] += 1
                added_carton = true
              end
            end

            # Stunningly, some Burlington vendors "can't" send subline prepack data on the 856, so they just
            # send the outer pack data.  In this case, we have to hit the PO and "explode" the prepack lines on
            # to this 856.
            if subline_count == 0
              outer_pack_quantity = find_element_value(item_loop[:segments], "SN102").to_i

              order_lines = explode_prepack(po_number, find_segment_qualified_value(find_segment(item_loop[:segments], "LIN"), "IN"))
              order_lines.each do |l|
                style = l.product.custom_value(cdefs[:prod_part_number])
                ordered_inner_packs = l.custom_value(cdefs[:ord_line_units_per_inner_pack]).to_i
                
                # It appears that what's happening here in this case is the PO has the same styles although the sizes are different (different skus)
                # then on the 856 there's no subline references to the distinct prepack line.  So, what happens then is that every
                # line has the same style.  Ultimately we'd like the 856 to link to distinct prepacks, so what we'll do is actually
                # include the order line on the po_data and just use the order/line number as the hash key so that we get the 
                # correct # of shipment lines added
                key = "#{po_number}*~*#{l.line_number}"
                po_data[key][:quantity] += BigDecimal(outer_pack_quantity * ordered_inner_packs)
                po_data[key][:order_line] = l unless po_data[key][:order_line]
                unless added_carton
                  po_data[key][:cartons] += 1
                  added_carton = true
                end
              end
            end
          else
            # Standard packs
            style = find_lin_style(item_loop[:segments])
            quantity = BigDecimal(find_element_value(item_loop[:segments], "SN102"))

            po_data[style][:quantity] += quantity
            po_data[style][:cartons] += 1
          end
        end
      end
    end

    process_po_data shipment, po, po_weights
  end

  def process_order_item_pack_loops shipment, hl_loops
    # In the 856, every single carton on the shipment is sent as individual Pack and Item 
    # loops.  We're obviously not going to create a distinct shipment line for each carton
    # so we'll roll everthing up to order/styles (the style on the 856 is actually the buyer style
    # on the order lines).
    po_weights = {}
    po = {}
    hl_loops[:hl_children].each do |po_loop|
      po_number = find_element_value(po_loop[:segments], "PRF01")
      td1 = find_segment(po_loop[:segments], "TD1")

      # Burlington doesn't send multiple lines on PO's...every PO "line" in their system is cut as 
      # a distinct 850 - the po # is 7 digits and the last 2 digits of the 9 digit number we receive
      # is the virtual line number.  What that means is that we'll never have multiple non-prepack items that
      # below to the same PO.  For the prepack items, we'll need to prorate this gross weight
      # based on the total item counts of each prepack.
      po_weights[po_number] = calculate_weight(td1)

      # This hash is just a style => {quantity:, cartons:} linkage
      po_data = po[po_number]
      if po_data.nil?
        po_data = Hash.new {|h, k| h[k] = {quantity: BigDecimal("0"), cartons: 0} }
        po[po_number] = po_data
      end

      po_loop[:hl_children].each do |item_loop|
        # really all we need at the pack level is the count of packs (cartons)
        cartons = item_loop[:hl_children].length
        uom = find_element_value(item_loop[:segments], "SN103")

        if uom == "AS"
          # Each prepack is a unique style that we'll add as a line on the shipment (since we explode 
          # prepacks on the order)
          # We don't have to do what we did with the 850 and multiply the prepack quantity by the 
          # Line's quantity.  In this case, the SN102 value is just the sum of the prepack quantities inside the carton.
          #
          # The only real catch is that since all of the prepacks are in the same carton we can't add a distinct
          # carton for every line..We'll work around that by just putting the carton amount on the first prepack
          # line and leaving the others with 0 cartons
          added_carton = false
          subline_count = 0
          find_segments(item_loop[:segments], "SLN") do |prepack|
            subline_count += 1
            style = find_style(prepack)
            quantity = BigDecimal(value(prepack, 4))
            po_data[style][:quantity] += quantity
            unless added_carton
              po_data[style][:cartons] += cartons
              added_carton = true
            end
          end

          # Stunningly, some Burlington vendors "can't" send subline prepack data on the 856, so they just
          # send the outer pack data.  In this case, we have to hit the PO and "explode" the prepack lines on
          # to this 856.
          # We can figure out the carton count, but we can't figure the quantity or the weight
          if subline_count == 0
            outer_pack_quantity = find_element_value(item_loop[:segments], "SN102").to_i

            order_lines = explode_prepack(po_number, find_segment_qualified_value(find_segment(item_loop[:segments], "LIN"), "IN"))
            order_lines.each do |l|
              style = l.product.custom_value(cdefs[:prod_part_number])
              ordered_inner_packs = l.custom_value(cdefs[:ord_line_units_per_inner_pack]).to_i
              
              # It appears that what's happening here in this case is the PO has the same styles although the sizes are different (different skus)
              # then on the 856 there's no subline references to the distinct prepack line.  So, what happens then is that every
              # line has the same style.  Ultimately we'd like the 856 to link to distinct prepacks, so what we'll do is actually
              # include the order line on the po_data and just use the order/line number as the hash key so that we get the 
              # correct # of shipment lines added
              key = "#{po_number}*~*#{l.line_number}"
              po_data[key][:quantity] += BigDecimal(outer_pack_quantity * ordered_inner_packs)
              po_data[key][:order_line] = l unless po_data[key][:order_line]
              unless added_carton
                po_data[key][:cartons] += cartons
                added_carton = true
              end
            end
          end
          
        else
          # Standard packs
          style = find_lin_style(item_loop[:segments])
          quantity = BigDecimal(find_element_value(item_loop[:segments], "SN102"))

          po_data[style][:quantity] += quantity
          po_data[style][:cartons] += cartons
        end
      end
    end

    process_po_data shipment, po, po_weights
  end

  def find_lin_style segments
    find_style(find_segment(segments, "LIN"))
  end

  def find_style segment
    style = find_segment_qualified_value(segment, "IN")

    if style.blank?
      style = find_segment_qualified_value(segment, "UP")
    end

    style
  end

  def explode_prepack order_number, outer_pack_identifier
    order = Order.where(importer_id: importer.id, order_number: "BURLI-#{order_number}").first
    raise EdiBusinessLogicError, "Burlington 856 references missing Order # '#{order_number}'." unless order

    order_lines = order.order_lines.find_all {|l| l.custom_value(cdefs[:ord_line_outer_pack_identifier]) == outer_pack_identifier}
    raise EdiBusinessLogicError, "Burlington 856 references missing Order Line from Order '#{order_number}' with Outer Pack Identifier '#{outer_pack_identifier}'." if order_lines.length == 0

    order_lines
  end

  def process_po_data shipment, po, po_weights
    # For each po / style combination we'll generate a distinct shipment line
    # Due to the 1 PO per line style that Burlington employs, Any po that has more than one style
    # means those styles are prepacks.
    po.each_pair do |po_number, styles|
      po_weight = po_weights[po_number]

      if styles.keys.length == 1
        # Standard Eaches Order Line
        style = styles.keys.first
        style_data = styles[style]

        process_shipment_line_data shipment, po_number, style_data[:cartons], style, style_data[:quantity], po_weight, style_data[:order_line]
      else
        # Prepacks
        prepack_quantities = {}
        styles.each_pair {|style, data| prepack_quantities[style] = data[:quantity] }

        weights = prorate_order_weight(po_weight, prepack_quantities)

        styles.each_pair do |style, style_data|
          process_shipment_line_data shipment, po_number, style_data[:cartons], style, style_data[:quantity], weights[style], style_data[:order_line]
        end
      end
    end
  end

  def calculate_weight td1
    weight = BigDecimal(value(td1, 7))
    uom = value(td1, 8)
    # We want this weight in KG so convert it if it's in LBs (it really )
    if uom == "LB"
      # Round this to the nearest 100th of a KG
      weight = (weight * BigDecimal("0.453592")).round(2)
    end
    weight
  end

  def prorate_order_weight total_weight, styles
    # Styles should be a hash containing the style numbers associated with the # of items shipped for the po.
    total_quantity = styles.values.sum

    # We may have no quantities if we get prepacks without any prepack data
    return {} if total_quantity.nil? || total_quantity == 0

    proration = total_weight / total_quantity
    weights = {}

    styles.each_pair do |style, weight|
      # Always truncate, we'll fill in the remaining amounts a 100th of a KG at a time
      # Until we've allocated every weight value
      weights[style] = (weight * proration).round(2, BigDecimal::ROUND_DOWN)
    end

    remainder = total_weight - weights.values.sum

    if remainder > 0
      # Technically, I think the remainder should be allocated based on the ration of quantities present on the
      # prepack lines.  However, for ease of programming, i'm going to just do it by dropping 1/100th of a KG
      # at a time into each "bucket" until there's no remainder left.
      #
      # It shouldn't really matter, since Kewill doesn't even support decimal values for the Gross Weight, so 
      # it'll all get rounded at the end anyway.
      remainder_step = BigDecimal("0.01")
      begin
        weights.keys.each do |style|
          weights[style] += remainder_step
          remainder -= remainder_step

          break if remainder <= 0
        end
      end while remainder > 0
    end

    weights
  end

  def process_shipment_line_data shipment, order_number, cartons, buyer_style_or_upc, item_quantity, weight, order_line
    if order_line.nil?
      order = Order.where(importer_id: importer.id, order_number: "BURLI-#{order_number}").first
      raise EdiBusinessLogicError, "Burlington 856 references missing Order # '#{order_number}'." unless order

      order_line = order.order_lines.find {|l| l.custom_value(cdefs[:ord_line_buyer_item_number]) == buyer_style_or_upc}

      if order_line.nil?
        order_line = order.order_lines.find {|l| l.sku == buyer_style_or_upc}
      end

      raise EdiBusinessLogicError, "Burlington 856 references missing Order Line from Order '#{order_number}' with Buyer Item Number / UPC '#{buyer_style_or_upc}'." unless order_line
    end

    container = shipment.containers.first
    line = shipment.shipment_lines.build
    line.product = order_line.product
    line.container = container
    line.quantity = item_quantity
    line.carton_qty = cartons
    line.gross_kgs = weight
    line.linked_order_line_id = order_line.id

    line
  end

  def ship_mode mode
    case mode
    when "A"; "Air"
    when "C"; "Consolidation"
    when "D"; "Parcel Post"
    when "E"; "Expedited Truck"
    when "H"; "Customer Pickup"
    when "L"; "Contract Carrier"
    when "M"; "Motor (Common Carrier)"
    when "O"; "Containerized Ocean"
    when "P"; "Private Carrier"
    when "R"; "Rail"
    when "S"; "Ocean"
    when "T"; "Best Way (Shippers Option)"
    when "U"; "Private Parcel Service"
    when "AE"; "Air Express"
    when "BU"; "Bus"
    when "CE"; "Customer Pickup / Customer's Expense"
    when "LT"; "Less Than Trailer Load (LTL)"
    when "SR"; "Supplier Truck"
    else
      nil
    end
  end

  def port port_code
    Port.where(unlocode: port_code).first
  end

  def find_or_create_shipment shipment_number, shipment_date, bucket, file
    reference = "BURLI-#{shipment_number}"
    shipment = nil
    Lock.acquire("Shipment-#{reference}") do
      s = Shipment.where(importer_id: importer.id, reference: reference).first_or_create! last_exported_from_source: shipment_date, importer_reference: shipment_number

      if process_file?(shipment_date, s)
        shipment = s
      end
    end

    if shipment
      Lock.with_lock_retry(shipment) do
        return nil unless process_file?(shipment_date, shipment)
        shipment.last_exported_from_source = shipment_date
        shipment.last_file_bucket = bucket
        shipment.last_file_path = file

        yield shipment
      end
    end
  end

  def process_file? file_date, shipment
    shipment.last_exported_from_source.nil? || file_date >= shipment.last_exported_from_source
  end

  def parse_date date_val
    Time.zone.parse(date_val) rescue nil
  end

  def cdefs
    @cd ||= self.class.prep_custom_definitions([:ord_line_buyer_item_number, :ord_line_outer_pack_identifier, :ord_line_units_per_inner_pack, :prod_part_number])
  end

  def importer
    @importer ||= Company.importers.where(system_code: "BURLI").first
    raise "Unable to find Burlington importer account with system code of: 'BURLI'." unless @importer

    @importer
  end

end; end; end; end