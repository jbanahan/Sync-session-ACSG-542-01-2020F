require 'open_chain/custom_handler/hm/hm_custom_definition_support'
module OpenChain; module CustomHandler; module Hm; class HmShipmentParser
  include OpenChain::CustomHandler::Hm::HmCustomDefinitionSupport
  def self.parse data, user
    Lock.acquire_for_class(self) do
      Shipment.transaction do
        cdefs = prep_custom_definitions CUSTOM_DEFINITION_INSTRUCTIONS.keys
        lines = data.lines
        mode, file_date = process_first_line lines[0]
        file_name, import_number = process_second_line lines[1]
        return unless file_name.match(/\.US$/) #only process US files
        vessel, voyage, etd, act_dest_code, receipt_location = process_fifth_line lines[4]
        con_num, con_size, con_type, seal, eta = process_eighth_line lines[7]
        importer = find_importer
        header_data = {mode:mode,import_number:import_number,file_date:file_date,vessel:vessel,voyage:voyage,etd:etd,con_num:con_num,con_size:con_size,con_type:con_type,seal:seal,eta:eta,importer:importer,act_dest_code:act_dest_code,user:user,receipt_location:receipt_location}
        shp = build_shipment header_data
        con = (header_data[:mode]=='Ocean' ? build_container(shp, header_data) : nil)
        build_lines shp, con, lines, cdefs, header_data
        raise "You do not have permission to edit this shipment." unless shp.can_edit?(user)
        shp.save!
        shp.create_snapshot user
        attach_file shp, data, "#{file_name}.txt"
      end
    end
  end

  def self.build_shipment hd
    s = Shipment.where(importer_reference:hd[:import_number],importer_id:hd[:importer].id,voyage:hd[:voyage]).where('created_at > ?',1.year.ago).first
    if s.nil?
      s = Shipment.new(
        reference:"HENNE-#{hd[:import_number]}-#{hd[:file_date]}",
        importer_reference:hd[:import_number],
        importer:hd[:importer],
        voyage:hd[:voyage],
        receipt_location:hd[:receipt_location]
      )
    end
    s.vessel = hd[:vessel]
    s.voyage = hd[:voyage]
    s.est_arrival_port_date = hd[:eta]
    s.est_departure_date = hd[:etd]
    s.mode = hd[:mode]
    s
  end

  def self.build_container shp, hd
    con = shp.containers.find {|c| c.container_number == hd[:con_num]}
    con = shp.containers.build(container_number:hd[:con_num]) unless con
    con.container_size = "#{hd[:con_size]}#{hd[:con_type]}"
    con.seal_number = "#{hd[:seal]}"
    con
  end

  def self.build_lines shp, con, lines, cdefs, hd
    lines.each do |ln|
      next if !ln.match(/^ \w/) || ln.match(/FCR\/HBL:/)
      build_line shp, con, ln, cdefs, hd
    end
  end

  def self.build_line shp, con, ln, cdefs, hd
    ord_num = ln[33,8].strip
    sl = shp.shipment_lines.find {|my_line|
      ol = my_line.order_lines.first
      on = ol.order.customer_order_number if ol
      on == ord_num
    }
    if sl.nil?
      sl = shp.shipment_lines.build
      p = Product.where(importer_id:shp.importer_id,unique_identifier:"HENNE-#{ord_num}").first_or_create!
      #it's ok to run this after create because the whole thing is in a transaction
      raise "You do not have permission to edit this product." unless p.can_edit?(hd[:user])
      p.update_custom_value! cdefs[:prod_part_number], ord_num
      sl.product = p
      sl.quantity = ln[56,6].strip
      sl.carton_qty = ln[62,7].strip
      sl.cbms = ln[79,11].strip
      sl.gross_kgs = ln[69,10].strip
      sl.fcr_number = ln[1,16].strip
      sl.container = con
      build_order_line sl, ln, ord_num, cdefs, hd
      build_invoice_line sl, ln, ord_num, hd
    end
  end

  def self.build_invoice_line sl, ln, ord_num, hd
    ci = CommercialInvoice.find_by_importer_id_and_invoice_number sl.shipment.importer_id, ord_num
    cl = nil
    if ci.nil?
      ci = CommercialInvoice.new(importer:sl.shipment.importer,
        invoice_number:ord_num
      )
      cl = ci.commercial_invoice_lines.build
    else
      cl = ci.commercial_invoice_lines.first
      cl = ci.commercial_invoice_lines.build if cl.nil?
    end
    raise "You do not have permission to edit this commercial invoice." unless ci.can_edit?(hd[:user])
    ci.save!
    sl.linked_commercial_invoice_line_id = cl.id
  end

  def self.build_order_line sl, ln, ord_num, cdefs, hd
    ol = sl.order_lines.first
    if ol.nil?
      o = Order.where(importer_id:sl.shipment.importer.id,
        order_number:"HENNE-#{ord_num}",
        customer_order_number:ord_num
      ).first_or_create!
      ol = o.order_lines.build(product:sl.product,quantity:sl.quantity)
      raise "You do not have permission to edit this order." unless o.can_edit?(hd[:user])
      o.save!
      sl.linked_order_line_id = ol.id
    elsif ol.quantity < sl.quantity
      ol.quantity = sl.quantity
      raise "You do not have permission to edit this order." unless ol.order.can_edit?(hd[:user])
      ol.save!
    end
    dest_code = ln[17,8].strip
    dest_code = hd[:act_dest_code] if dest_code.blank?
    ol.update_custom_value! cdefs[:ol_dest_code], dest_code
    ol.update_custom_value! cdefs[:ol_dept_code], ln[47,9].strip
  end

  def self.find_importer
    importer = Company.find_by_system_code 'HENNE'
    raise "Importer with system code 'HENNE' not found." unless importer
    importer
  end

  def self.attach_file s, data, file_name
    t = Tempfile.new('x')
    begin
      Attachment.add_original_filename_method t
      t.original_filename = file_name
      t.write data
      t.rewind
      att = s.attachments.build
      att.attached = t
      att.save!
    ensure
      t.close
      t.unlink
    end
  end

  # FIRST LINE STUFF

  def self.process_first_line line
    validate_first_line line
    mode = find_mode line
    file_date = find_file_date line
    [mode, file_date]
  end

  def self.validate_first_line line
    if !line.match /^TRANSPORT INFORMATION/
      raise "First line must start with TRANSPORT INFORMATION (#{line})"
    end
    true
  end

  def self.find_mode line
    r = ''
    case line
    when /AIR FREIGHT DETAIL/
      r = 'Air'
    when /SEA FREIGHT DETAIL/
      r = 'Ocean'
    end
    r
  end

  def self.find_file_date line
    line.match(/\d{2}-[A-Z]{3}-\d{4}/).to_s
  end

  # SECOND LINE STUFF

  def self.process_second_line line
    if !line.match /^Filename/
      raise "Second line must start with Filename (#{line})"
    end
    split_line = line.split(' ')
    raise "Import number should be all digits" unless split_line[3].match /^\d+$/
    [split_line[1],split_line[3]]
  end

  # FIFTH LINE STUFF

  def self.process_fifth_line line
    act_dest_code = line[24,10].strip
    vessel = line[34,20].strip
    voyage = line[54,12].strip
    receipt_location = line[66,18].strip
    etd = parse_date(line[122,6])
    [vessel,voyage,etd,act_dest_code,receipt_location]
  end

  # EIGTH LINE STUFF

  def self.process_eighth_line line
    container_number = line[1,17].strip
    container_size = line[18,6].strip
    container_type = line[24,6].strip
    seal = line[30,16].strip
    eta = parse_date(line[122,6])
    [container_number,container_size,container_type,seal,eta]
  end

  def self.parse_date str
    Date.new("20#{str[0,2]}".to_i,str[2,2].to_i,str[4,2].to_i)
  end

end; end; end; end;
