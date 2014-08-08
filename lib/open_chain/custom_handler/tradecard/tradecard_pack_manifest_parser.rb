require 'open_chain/xl_client'

module OpenChain; module CustomHandler; module Tradecard; class TradecardPackManifestParser

  def self.parse shipment, path, user
    self.new.run(shipment,OpenChain::XLClient.new(path),user)
  end

  def run shipment, xl_client, user
    process_rows shipment, xl_client.all_row_values, user
  end

  def process_rows shipment, rows, user
    ActiveRecord::Base.transaction do
      raise "You do not have permission to edit this shipment." unless shipment.can_edit?(user)
      validate_heading rows
      add_containers shipment, rows if mode(rows)=='OCEAN'
      add_lines shipment, rows
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
      break if row.size < 4 || row[3].blank? || !row[3].match(/\d$/)
      cnum = row[3]
      if shipment.containers.find {|con| con.container_number == cnum}.nil?
        shipment.containers.build(container_number:cnum)
      end
      cursor += 1
    end
  end

  def add_lines shipment, rows
    carton_detail_header_row = header_row_index(rows,'CARTON DETAIL')
    return unless carton_detail_header_row
    cursor = carton_detail_header_row+2
    container = nil
    while cursor < rows.size
      r = rows[cursor]
      cursor += 1
      if r.size > 3 && !r[3].blank? && r[3].match(/^Equipment/)
        equip_num = r[3].split(' ')[1]
        container = shipment.containers.find {|con| con.container_number == equip_num}
        next
      end
      if r.size==57 && !r[29].blank? && r[29].match(/\d/)
        add_line shipment, r, container
        next
      end
    end
  end

  def add_line shipment, row, container
    po = row[14]
    sku = row[20]
    qty = clean_number(row[29])
    ol = find_order_line shipment, po, sku
    sl = shipment.shipment_lines.build(product:ol.product,quantity:qty)
    sl.container = container
    sl.linked_order_line_id = ol.id
  end

  def clean_number num
    return nil if num.blank?
    num.to_s.gsub(',','').strip
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

  def header_row_index rows, name
    rows.index {|r| r.size > 1 && r[1]==name}
  end
end; end; end; end