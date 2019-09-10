require 'open_chain/xl_client'
require 'open_chain/custom_handler/shipment_parser_support'

module OpenChain; module CustomHandler; module Tradecard; class TradecardPackManifestParser
  include OpenChain::CustomHandler::ShipmentParserSupport
  
  def self.process_attachment shipment, attachment, user, opts = {}
    parse shipment, attachment.attached.path, user, opts[:manufacturer_address_id], opts[:enable_warnings]
  end
  def self.parse shipment, path, user, manufacturer_address_id=nil, enable_warnings=nil
    self.new.run(shipment,OpenChain::XLClient.new(path),user, manufacturer_address_id, enable_warnings)
  end

  def run shipment, xl_client, user, manufacturer_address_id=nil, enable_warnings=nil
    process_rows shipment, xl_client.all_row_values, user, manufacturer_address_id, enable_warnings
  end

  def process_rows shipment, rows, user, manufacturer_address_id=nil, enable_warnings=nil
    ActiveRecord::Base.transaction do
      raise_error("You do not have permission to edit this shipment.") unless shipment.can_edit?(user)
      validate_heading rows
      # Containers should be added first...the lines parsing also updates container data
      add_containers shipment, rows if mode(rows)=='OCEAN'
      lines_added = add_lines user, shipment, rows, manufacturer_address_id, enable_warnings
      add_totals(shipment, lines_added)
      shipment.save!
    end
  end

  private
  def validate_heading rows
    if rows.size < 2 || rows[1].size < 2 || rows[1][1].blank? || !rows[1][1].to_s == 'Packing Manifest'
      raise_error("INVALID FORMAT: Cell B2 must contain 'Packing Manifest'.")
    end
  end

  def mode rows
    rows.collect { |row| 
      (row.size >= 8 && row[4] == 'Method') ? row[11] : nil
    }.compact.first
  end

  def add_containers shipment, rows
    equipment_header_row = header_row_index(rows,'EQUIPMENT SUMMARY')
    return unless equipment_header_row
    cursor = equipment_header_row+2
    while cursor < rows.size
      row = rows[cursor]
      cursor += 1
      next if !row[3].blank? && row[3].to_s.match(/Equipment/)
      break if row.size < 4 || row[3].blank? || !row[3].to_s.match(/\d$/)
      cnum = row[3]
      if shipment.containers.find {|con| con.container_number == cnum}.nil?
        shipment.containers.build(container_number:cnum)
      end
    end
  end

  def add_lines user, shipment, rows, manufacturer_address_id, enable_warnings
    max_line_number = 0
    shipment.shipment_lines.each {|sl| max_line_number = sl.line_number if sl.line_number && sl.line_number > max_line_number }
    carton_detail_header_row = header_row_index(rows,'CARTON DETAIL', 'PACKAGE DETAIL')

    return unless carton_detail_header_row
    cursor = carton_detail_header_row+2

    parse_container_summary_info(shipment, rows[cursor]) unless shipment.mode.to_s.upcase == "AIR"
    container = nil
    lines_added = []
    while cursor < rows.size
      r = rows[cursor]
      cursor += 1
      if r.size > 3 && !r[3].blank? && r[3].to_s.match(/^Equipment/)
        equip_num = r[3].to_s.split(' ')[1]
        container = shipment.containers.find {|con| con.container_number == equip_num}
        next
      end
      if r.size==57 && !r[29].blank? && r[29].to_s.match(/\d/)
        max_line_number += 1
        lines_added << add_line(shipment, r, container, max_line_number, manufacturer_address_id)
      end
    end
    review_orders user, shipment, enable_warnings
    lines_added
  end

  def add_line shipment, row, container, line_number, manufacturer_address_id
    po = OpenChain::XLClient.string_value row[14]
    sku = OpenChain::XLClient.string_value row[20]
    qty = clean_number(row[29])
    ol = find_order_line shipment, po, sku
    sl = shipment.shipment_lines.build(product:ol.product,quantity:qty, manufacturer_address_id:manufacturer_address_id)
    sl.gross_kgs = BigDecimal("0")
    sl.carton_qty = 0
    sl.cbms = BigDecimal("0")
    sl.container = container
    sl.linked_order_line_id = ol.id
    sl.line_number = line_number
    sl.carton_set = find_or_build_carton_set shipment, row

    sl
  end

  def review_orders user, shipment, enable_warnings
    ord_nums = order_cache.values.map(&:order_number)
    flag_unaccepted ord_nums
    if enable_warnings
      warn_for_manifest(ord_nums, shipment)
    else
      shipment.warning_overridden_at = Time.zone.now
      shipment.warning_overridden_by = user
    end
  end

  def clean_number num
    return nil if num.blank?
    num.to_s.gsub(',','').strip
  end

  def convert_number num, conversion
    n = clean_number num
    return nil if n.nil?
    (BigDecimal(n) * conversion).round(4, BigDecimal::ROUND_HALF_UP)
  end

  def find_order_line shipment, po, sku
    ord = order_cache[po]
    if ord.nil?
      ord = Order.where(customer_order_number:po,importer_id:shipment.importer_id).includes(:order_lines).first
      raise_error("Order Number #{po} not found.") unless ord
      order_cache[po] = ord
    end
    ol = ord.order_lines.find {|ln| ln.sku == sku}
    raise_error("SKU #{sku} not found in order #{po} (ID: #{ord.id}).") unless ol
    ol
  end

  def order_cache
    @order_cache ||= {}
  end

  def find_or_build_carton_set shipment, row
    initial_starting_carton = row[6]
    cs = nil
    if initial_starting_carton.blank?
      # If the initial starting carton column is left blank, it just means the same carton range from the previous
      # row is still in use
      cs = shipment.carton_sets.to_a.last
    end

    return cs unless cs.nil?

    # Regardless of what was sent in the Excel, make this an int to ensure we re-use values we've seen before
    starting_carton = initial_starting_carton.to_i
    if cs.nil?
      # See if the Carton Set has already been added
      cs = shipment.carton_sets.find { |cs| cs.starting_carton == starting_carton }
      return cs unless cs.nil?

      cs = shipment.carton_sets.build(starting_carton: starting_carton)
    end

    weight_factor = (row[48].to_s.strip == 'LB') ? BigDecimal("0.453592") : 1
    dim_factor = dimension_coversion_factor(row[55].to_s.strip)
    
    cs.carton_qty = clean_number row[37]
    cs.net_net_kgs = convert_number row[42], weight_factor
    cs.net_kgs = convert_number row[45], weight_factor
    cs.gross_kgs = convert_number row[47], weight_factor
    cs.length_cm = convert_number row[49], dim_factor
    cs.width_cm = convert_number row[51], dim_factor
    cs.height_cm = convert_number row[53], dim_factor

    cs
  end

  def header_row_index rows, *names
    rows.index {|r| r.size > 1 && names.include?(r[1].to_s.upcase)}
  end

  def parse_container_summary_info shipment, row
    regex = /Equipment\s*#\s*:\s*(.*)Type\s*:\s*(.*)Seal\s*#\s*:\s*(.*)/i
    cell = row.find {|c| c.to_s.match regex}

    return nil if cell.blank?

    info = cell.scan regex
    if info.length > 0
      container_number, size, seal = *info.flatten

      container = shipment.containers.find {|c| c.container_number.to_s.upcase == container_number.strip.upcase}

      if container
        # Don't overwrite potential existing data w/ nil/blank data...

        # Seal is often sent to us as "NULL" (java alert), if there isn't one associated w/ the container on the manifest
        container.seal_number = seal.strip unless (seal.blank? || seal.upcase == "NULL")
        size = Container.parse_container_size_description size
        container.container_size = size unless size.blank?
      end
    end
  end

  def add_totals shipment, lines_added
    gross_weight = BigDecimal(0)
    total_package_count = 0
    volume = BigDecimal(0)

    carton_sets = Set.new
    Array.wrap(lines_added).each do |line|
      cs = line.carton_set
      next if cs.nil? || carton_sets.include?(cs)

      total_package_count += cs.carton_qty.presence || 0
      gross_weight += cs.total_gross_kgs(3)
      volume += cs.total_volume_cbms(3)

      carton_sets << cs
    end
    
    shipment.volume = (shipment.volume.presence || BigDecimal(0)) + volume
    shipment.gross_weight = (shipment.gross_weight.presence || BigDecimal(0)) + gross_weight
    # Only add packages to total if the uom is blank or cartons
    if shipment.number_of_packages_uom.blank? || shipment.number_of_packages_uom =~ /(CTN|CARTON)/i
      shipment.number_of_packages = (shipment.number_of_packages.presence || 0) + total_package_count
      shipment.number_of_packages_uom = "CARTONS" if shipment.number_of_packages_uom.blank?
    end

    sum_carton_set_shipment_line_data(shipment, lines_added) unless lines_added.blank?
    nil
  end

  def sum_carton_set_shipment_line_data shipment, lines_added
    # We need to calculate the number of cartons per shipment line and the gross weight / volume
    # and then prorate those values to the line for lines where there's multiple shipment lines per carton set
    carton_sets = {}
    lines_added.each do |line|
      carton_sets[line.carton_set] ||= []
      carton_sets[line.carton_set] << line
    end

    carton_sets.each_pair do |cs, lines|
      total_cartons = (cs.carton_qty.presence || 0)
      total_weight = cs.total_gross_kgs(4)
      

      if lines.length == 1
        line = lines[0]
        line.carton_qty = total_cartons
        line.gross_kgs = total_weight
        line.cbms = cs.total_volume_cbms(4)
      elsif lines.length > 0
        total_items = lines.sum {|l| l.quantity.to_f > 0 ? l.quantity : 0 }

        # Do the proration as cubic centimeters (since it's so small), then convert to cbms
        total_volume = cs.total_volume_cubic_centimeters

        prorate_based_on_item_count(total_weight, total_items, lines, "gross_kgs")
        prorate_based_on_item_count(total_volume, total_items, lines, "cbms")
        # Because we're potentially losing some data on the round below, add it back in
        cbms = cs.total_volume_cbms(4)
        total = BigDecimal("0")
        lines.each do |line|
          if !line.cbms.nil?
            line.cbms = (line.cbms / BigDecimal(1000000)).round(4, BigDecimal::ROUND_DOWN)
            total += line.cbms
          end
        end

        if total < cbms
          lines.first.cbms ||= BigDecimal("0")
          lines.first.cbms += (cbms - total)
        end
        
        prorate_carton(total_cartons, lines)
      end
    end

  end

  def prorate_based_on_item_count total_amount, total_items, shipment_lines, attribute
    proration = (BigDecimal(total_amount.to_s) / BigDecimal(total_items.to_s)).round(2, BigDecimal::ROUND_DOWN)

    total_prorated = BigDecimal("0")
    shipment_lines.each do |line|
      amount = (proration * line.quantity).round(4, BigDecimal::ROUND_DOWN)
      line.assign_attributes(attribute => amount)
      total_prorated += amount
    end

    # This basically means that there's no values (units / items) to prorate..so bail.
    return if total_prorated == 0

    remainder = total_amount - total_prorated

    return unless remainder > 0

    begin
      shipment_lines.each do |line|
        # TODO Figure out prorations of very small values without 
        if remainder < BigDecimal("0.0099")
          val = line.attributes[attribute.to_s]
          line.assign_attributes({attribute => (val + remainder)})
          remainder = 0
          break
        else
          val = line.attributes[attribute.to_s]
          proration_unit = BigDecimal("0.01")
          line.assign_attributes({attribute => (val + proration_unit)})
          remainder -= proration_unit
          break if remainder <= 0
        end
      end
    end while remainder > 0
  end

  def prorate_carton total_cartons, shipment_lines
    carton_used = 0
    begin
      shipment_lines.each do |line|
        carton_used += 1
        line.carton_qty += 1
        break if carton_used >= total_cartons
      end
    end while carton_used < total_cartons
  end

  def dimension_coversion_factor uom
    case uom
    when "IN"
      BigDecimal("2.54")
    when "MR"
      BigDecimal(100)
    when "FT"
      BigDecimal("30.48")
    else
      BigDecimal(1)
    end
  end
end; end; end; end
