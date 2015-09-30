require 'open_chain/xl_client'

module OpenChain; module CustomHandler; module Tradecard; class TradecardPackManifestParser

  def self.process_attachment shipment, attachment, user, manufacturer_address_id=nil
    parse shipment, attachment.attached.path, user, manufacturer_address_id
  end
  def self.parse shipment, path, user, manufacturer_address_id=nil
    self.new.run(shipment,OpenChain::XLClient.new(path),user, manufacturer_address_id)
  end

  def run shipment, xl_client, user, manufacturer_address_id=nil
    process_rows shipment, xl_client.all_row_values, user, manufacturer_address_id
  end

  def process_rows shipment, rows, user, manufacturer_address_id=nil
    ActiveRecord::Base.transaction do
      raise "You do not have permission to edit this shipment." unless shipment.can_edit?(user)
      validate_heading rows
      # Containers should be added first...the lines parsing also updates container data
      add_containers shipment, rows if mode(rows)=='OCEAN'
      lines_added = add_lines shipment, rows, manufacturer_address_id
      add_totals(shipment, lines_added)
      shipment.save!
    end
  end

  private
  def validate_heading rows
    if rows.size < 2 || rows[1].size < 2 || rows[1][1].blank? || !rows[1][1].to_s == 'Packing Manifest'
      raise "INVALID FORMAT: Cell B2 must contain 'Packing Manifest'."
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

  def add_lines shipment, rows, manufacturer_address_id
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

    lines_added
  end

  def add_line shipment, row, container, line_number, manufacturer_address_id
    po = OpenChain::XLClient.string_value row[14]
    sku = OpenChain::XLClient.string_value row[20]
    qty = clean_number(row[29])
    ol = find_order_line shipment, po, sku
    sl = shipment.shipment_lines.build(product:ol.product,quantity:qty, manufacturer_address_id:manufacturer_address_id)
    sl.container = container
    sl.linked_order_line_id = ol.id
    sl.line_number = line_number
    sl.carton_set = find_or_build_carton_set shipment, row

    sl
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
    @order_cache ||= Hash.new
    ord = @order_cache[po]
    if ord.nil?
      ord = Order.where(customer_order_number:po,importer_id:shipment.importer_id).includes(:order_lines).first
      raise "Order Number #{po} not found." unless ord
      @order_cache[po] = ord
    end
    ol = ord.order_lines.find {|ln| ln.sku == sku}
    raise "SKU #{sku} not found in order #{po} (ID: #{ord.id})." unless ol
    ol
  end

  def find_or_build_carton_set shipment, row
    starting_carton = row[6]
    return @last_carton_set if starting_carton.blank?

    # Regardless of what was sent in the Excel, make this an int to ensure we re-use values we've seen before
    starting_carton = starting_carton.to_i

    cs = shipment.carton_sets.to_a.find {|cs| cs.starting_carton == starting_carton} #don't hit DB since we haven't saved
    if cs.nil?
      weight_factor = (row[48].to_s.strip == 'LB') ? BigDecimal("0.453592") : 1
      dim_factor = (row[55].to_s.strip =='IN') ? BigDecimal("2.54") : 1
      cs = shipment.carton_sets.build(starting_carton:starting_carton)
      cs.carton_qty = clean_number row[37]
      cs.net_net_kgs = convert_number row[42], weight_factor
      cs.net_kgs = convert_number row[45], weight_factor
      cs.gross_kgs = convert_number row[47], weight_factor
      cs.length_cm = convert_number row[49], dim_factor
      cs.width_cm = convert_number row[51], dim_factor
      cs.height_cm = convert_number row[53], dim_factor
      @last_carton_set = cs
    end
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
      gross_weight += cs.total_gross_kgs
      volume += cs.total_volume_cbms

      carton_sets << cs
    end
    
    shipment.volume = (shipment.volume.presence || BigDecimal(0)) + volume
    shipment.gross_weight = (shipment.gross_weight.presence || BigDecimal(0)) + gross_weight
    # Only add packages to total if the uom is blank or cartons
    if shipment.number_of_packages_uom.blank? || shipment.number_of_packages_uom =~ /(CTN|CARTON)/i
      shipment.number_of_packages = (shipment.number_of_packages.presence || 0) + total_package_count
      shipment.number_of_packages_uom = "CARTONS" if shipment.number_of_packages_uom.blank?
    end
  end
end; end; end; end