module OpenChain
  class UnderArmourExportParser
    def self.parse_csv_file file_path
      count = 0
      File.new(file_path).lines do |line|
        parse_csv_line line unless count == 0
        puts "Processed Line #{count}" if count.modulo(100)==0
        count += 1
      end
    end

    # parses line and returns a saved DutyCalcExportFileLine
    def self.parse_csv_line line
      d = DutyCalcExportFileLine.new
      CSV.parse(line) do |r|
        d.export_date = Date.strptime(r[15],"%Y%m%d")
        d.ship_date = d.export_date
        d.part_number = get_part_number r[5]
        d.ref_1 = numeric_to_string r[1]
        d.ref_2 = numeric_to_string r[0]
        d.destination_country = r[14]
        d.quantity = r[8]
        d.schedule_b_code = r[17].gsub(".","")
        d.description = r[7]
        d.uom = "EA"
        d.exporter = "Under Armour"
        d.action_code = "E"
      end
      d.save!
      d
    end

    def self.parse_fmi_csv_file file_path
      count = 0
      File.new(file_path).lines do |line|
        parse_fmi_csv_line line unless count == 0
        puts "Processed Line #{count}" if count.modulo(100)==0
        count += 1
      end
    end

    # parses line from FMI outbound format
    def self.parse_fmi_csv_line line
      d = DutyCalcExportFileLine.new
      CSV.parse(line) do |r|
        d.export_date = Date.strptime(r[4],"%m/%d/%Y")
        d.ship_date = d.export_date
        d.part_number = "#{r[6]}-#{r[8]}+#{r[1]}"
        d.ref_1 = r[0]
        d.ref_2 = r[3]
        d.destination_country = r[11]
        d.quantity = r[19]
        d.description = r[7]
        d.uom = "EA"
        d.exporter = "Under Armour"
        d.action_code = "E"
      end
      d.save!
      d
    end


    def self.numeric_to_string s
      s.to_s.ends_with?(".0") ? s.to_s[0,s.to_s.size-2] : s.to_s
    end
    def self.get_part_number combined_string
      a = combined_string.split('-')
      "#{a[1]}-#{a[2]}-#{a[3]}+#{a[4]}"
    end
  end
end
