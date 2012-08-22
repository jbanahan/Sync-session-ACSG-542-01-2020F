module OpenChain
  class UnderArmourExportParser
    def self.parse_csv_file file_path
      count = 0
      File.new(file_path).lines do |line|
        parse_csv_line line, (count+1) unless count == 0
        puts "Processed Line #{count}" if count.modulo(100)==0
        count += 1
      end
    end

    # parses line and returns a saved DutyCalcExportFileLine
    def self.parse_csv_line line, row_num = nil
      d = DutyCalcExportFileLine.new
      CSV.parse(line) do |r|
        raise "Line #{row_num} had #{r.size} elements.  All lines must have 32 elements." unless r.size==32
        d.export_date = Date.strptime(r[18],"%Y%m%d")
        d.ship_date = d.export_date
        d.part_number = get_part_number r
        d.ref_1 = numeric_to_string r[1]
        d.ref_2 = numeric_to_string r[0]
        d.destination_country = r[17]
        d.quantity = r[7]
        d.schedule_b_code = r[20].gsub(".","")
        d.description = r[6]
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

    def self.parse_aafes_csv_file file_path
      AafesParser.new(file_path).go
    end


    def self.numeric_to_string s
      s.to_s.ends_with?(".0") ? s.to_s[0,s.to_s.size-2] : s.to_s
    end
    def self.get_part_number row
      style = row[2]
      color = row[3]
      size = row[4]
      coo = row[5]
      while color.size < 3
        color = "0"+color
      end
      [style,color,size,coo].each {|x| raise "Invalid item SKU #{style}-#{color}-#{size}+#{coo}" if x.blank?}
      "#{style}-#{color}-#{size}+#{coo}"
    end

    class AafesParser
      def initialize file_path
        @file_path = file_path
      end

      def go
        msgs = []
        count = 0
        CSV.foreach(@file_path) do |line|
          m = parse_line line unless count == 0
          msgs << m unless m.nil?
          puts "Processed Line #{count}" if count.modulo(100)==0
          count += 1
        end
        msgs
      end

      def parse_line line
        style_color = line[0]
        color = line[1]
        date_pieces = line[5].split("/")
        export_date = Date.new(date_pieces.last.to_i,date_pieces.first.to_i,date_pieces[1].to_i)
        coo = find_country_of_origin style_color, export_date
        return "Could not find country of origin for #{style_color} #{export_date}." if coo.blank?
        DutyCalcExportFileLine.create!(:export_date=>export_date,:ship_date=>export_date,:ref_1=>line[3],:ref_2=>line[4],:ref_3=>"AAFES - NOT FOR ABI",
          :destination_country=>line[12], :quantity=>line[18],:description=>line[15],:uom=>'EA',:action_code=>'E',:part_number=>"#{style_color}-#{line[1]}+#{coo}")
        nil
      end

      def find_country_of_origin style_color, export_date
        d_line = DrawbackImportLine.where("part_number LIKE ?","#{style_color}%").where("import_date <= ?",export_date).order("import_date DESC").limit(1).first
        d_line.nil? ? nil : d_line.part_number.split("+").last
      end
    end
  end
end
