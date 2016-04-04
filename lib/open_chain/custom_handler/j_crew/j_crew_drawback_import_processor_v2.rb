require 'csv'
module OpenChain; module CustomHandler; module JCrew; class JCrewDrawbackImportProcessorV2
  # fields prefixed with entry_ original came from the VFI Track entry
  # fields prefixed with crew_ came from the J Crew host system(s)
  DATA_ROW_STRUCT ||= Struct.new(
    :file_line_number,
    :entry_number,
    :entry_mbol,
    :entry_hbol,
    :entry_arrival_date,
    :entry_po,
    :entry_part,
    :entry_coo,
    :entry_units,
    :crew_mbol,
    :crew_po,
    :crew_mode,
    :crew_style,
    :crew_sku,
    :crew_order_line_number,
    :crew_asn_pieces,
    :crew_order_pieces,
    :crew_ship_date,
    :crew_asn_ship_mode,
    :crew_unit_cost
  ) do
    # return nil if good and error message if bad
    def validate!
      validate_equality!('PO',self.entry_po,self.crew_po)
      validate_equality!('Style',self.entry_part,self.crew_style)
      validate_equality!('Master Bill',self.entry_mbol,self.crew_mbol)
      # if self.crew_asn_ship_mode=='Sea' && self.crew_ship_date > self.entry_arrival_date
      #   raise "Error on line #{file_line_number}: Ship date #{self.crew_ship_date.strftime('%Y-%m-%d')} is after arrival date #{self.entry_arrival_date.strftime('%Y-%m-%d')}."
      # end
    end
    def po_style
      "#{self.entry_po}~#{self.entry_part}"
    end

    def validate_equality! label, expected, found
      if expected!=found
        raise "Error on line #{file_line_number}: Expected #{label} #{expected} found #{found}."
      end
    end
  end

  def self.parse_csv_file path, user
    parse(IO.read(path),user)
  end

  def self.parse data, user
    ds = build_data_structure(data)
    log = process_data(ds,user)
    if !log.empty?
      OpenMailer.send_simple_text(
        user.email,
        'J Crew Drawback Import V2 Error Log',
        "**J Crew Drawback Import V2 Error Log**\n#{log.join("\n")}"
      ).deliver!
    end
    log
  end

  def self.process_data data_structure, user
    log = []
    if log.empty?
      data_structure.each do |entry_number,po_part_hash|
        begin
          process_entry(entry_number,po_part_hash)
        rescue
          log << $!.message
        end
      end
    end
    log
  end

  def self.process_entry entry_number, po_part_hash
    Entry.transaction do
      crew = Company.find_by_alliance_customer_number('JCREW')
      ent = Entry.where('entries.customer_number IN (?)',['JCREW','J0000']).where(entry_number:entry_number).first
      if ent.blank?
        raise "Entry #{entry_number} not found."
      end
      if DrawbackImportLine.where(entry_number:entry_number).count > 0
        raise "Entry #{entry_number} already has drawback lines."
      end
      po_part_hash.values.each do |structs|
        base_struct = structs.first
        target = base_struct.entry_units
        found = structs.inject(0) {|mem,s| mem + s.crew_asn_pieces}
        if target != found
          raise "Entry #{entry_number}, PO #{base_struct.entry_po}, Part #{base_struct.entry_part} should have had #{base_struct.entry_units} pieces but found #{found}."
        end
      end
      po_part_hash.values.each do |structs|
        first_struct = structs.first
        ci_lines = ent.commercial_invoice_lines.where(
          part_number:first_struct.entry_part,
          po_number:first_struct.entry_po,
          quantity:first_struct.entry_units,
          country_origin_code:first_struct.entry_coo
        )
        if(ci_lines.size > 1)
          raise "Entry #{entry_number}, PO #{first_struct.entry_po}, Part #{first_struct.entry_part} has multiple commercial invoice lines."
        elsif ci_lines.blank?
          raise "Entry #{entry_number}, PO #{first_struct.entry_po}, Part #{first_struct.entry_part}, Quantity #{first_struct.entry_units} not found."
        end
        ci_line = ci_lines.first
        tariff_line = ci_line.commercial_invoice_tariffs.first

        fob_price = structs.inject(BigDecimal("0.00")) {|mem,obj| mem += (obj.crew_unit_cost * obj.crew_asn_pieces)}
        discount_rate = tariff_line.entered_value / fob_price

        p = Product.where(unique_identifier:"JCREW-#{ci_line.part_number}").first_or_create!

        structs.each do |s|
          unit_price = s.crew_unit_cost * discount_rate
          unit_price = unit_price.round(2)
          DrawbackImportLine.create!(
            entry_number:ent.entry_number,
            import_date: ent.arrival_date,
            received_date: ent.arrival_date,
            port_code: ent.entry_port_code,
            box_37_duty: ent.total_duty,
            box_40_duty: ent.total_duty_direct,
            total_mpf: ent.mpf,
            country_of_origin_code: ci_line.country_origin_code,
            part_number: s.crew_sku,
            hts_code: tariff_line.hts_code,
            description: tariff_line.tariff_description,
            unit_of_measure: ci_line.unit_of_measure,
            unit_price: unit_price,
            rate: tariff_line.duty_rate,
            duty_per_unit: (unit_price * tariff_line.duty_rate).round(5),
            compute_code: '7',
            ocean: ent.transport_mode_code=='11',
            total_invoice_value: ent.entered_value,
            quantity: s.crew_asn_pieces,
            importer_id: crew.id,
            product_id: p.id
          )
        end
      end
    end
  end

  def self.find_used_entries entry_numbers
    r = []
    entry_numbers.in_groups_of(500) do |nums|
      r += DrawbackImportLine.where('entry_number IN (?)',nums).pluck(:entry_number).uniq
    end
    r.uniq.compact
  end

  def self.build_data_structure data
    h = {}
    row_number = 0
    CSV.parse(data,headers:true) do |row|
      row_number += 1
      struct = parse_line(row_number,row)
      struct.validate!
      h[struct.entry_number] ||= {}
      po_part_hash = h[struct.entry_number]
      po_part_hash[struct.po_style] ||= []
      po_part_hash[struct.po_style] << struct
    end
    return h
  end

  def self.parse_line row_number, line
    DATA_ROW_STRUCT.new(
      row_number,
      line[1],
      line[2],
      line[3]=='NULL' ? nil : line[3],
      parse_date(line[5]),
      line[6],
      line[7],
      line[8],
      line[9].to_i,
      line[10],
      line[11],
      line[13],
      line[14],
      line[18],
      line[19],
      line[20].to_i,
      line[21].to_i,
      parse_date(line[22]),
      line[24],
      BigDecimal(line[25].gsub('$',''))
    )
  end

  def self.parse_date str
    el = str.split('/')
    Date.new(el.last.to_i,el.first.to_i,el[1].to_i)
  end

end; end; end end;
