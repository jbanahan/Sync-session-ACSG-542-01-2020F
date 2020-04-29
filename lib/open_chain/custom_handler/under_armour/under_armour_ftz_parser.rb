module OpenChain; module CustomHandler; module UnderArmour
  # Creates import lines for FTZ shipments that ALREADY HAVE existing duty_calc_export_file_lines based on the
  # delivery number matching reference 1 in the export line
  class UnderArmourFtzParser
    def initialize total_entered_value, mpf, entry_date, port_code, box_37_value, box_40_value
      @total_entered_value = total_entered_value
      @entry_date = entry_date
      @mpf = mpf
      @port_code = port_code
      @box_37_value = box_37_value
      @box_40_value = box_40_value
    end

    def process_csv file_path
      CSV.foreach(file_path) do |r|
        if matches_export? r[2]
          make_import_line r
        end
      end
    end

    private
    def make_import_line r
      unit_price = BigDecimal(r[8]) / r[5].to_i
      duty_per_unit = BigDecimal(r[9]) / r[5].to_i
      p = Product.find_or_create_by(unique_identifier: r[3])
      dil = DrawbackImportLine.where(entry_number: r[1].gsub('-', ''), part_number: "#{r[3]}-#{r[4]}+#{r[6]}", quantity: r[5]).first
      if dil.nil?
        DrawbackImportLine.create!(
          :entry_number => r[1].gsub('-', ''),
          :part_number => "#{r[3]}-#{r[4]}+#{r[6]}",
          :quantity => r[5],
          :product_id => p.id,
          :import_date=>@entry_date,
          :received_date=>@entry_date,
          :port_code=>@port_code,
          :box_37_duty => @box_37_value,
          :box_40_duty => @box_40_value,
          :total_invoice_value => @total_entered_value,
          :total_mpf => @mpf,
          :country_of_origin_code => r[6],
          :hts_code => r[7],
          :description => r[13],
          :unit_of_measure => "EA",
          :unit_price => unit_price,
          :rate => r[10],
          :duty_per_unit => duty_per_unit
        )
      end
    end

    def matches_export? delivery_number
      @export_cache ||= {}
      @export_cache[delivery_number] = ( DutyCalcExportFileLine.where(:ref_1=>delivery_number).count > 0 ) if @export_cache[delivery_number].nil?
      @export_cache[delivery_number]
    end
  end
end; end; end
