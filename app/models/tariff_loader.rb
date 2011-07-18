class TariffLoader
  
  IMPORT_REG_LAMBDA = lambda {|o,d|
    s = o.import_regulations
    s = "" if s.nil?
    s << " #{d}"
    o.import_regulations = s.strip
  }
  EXPORT_REG_LAMBDA = lambda {|o,d|
    s = o.export_regulations
    s = "" if s.nil?
    s << " #{d}"
    o.export_regulations = s.strip
  }

  FIELD_MAP = {
    "HSCODE" => lambda {|o,d| o.hts_code = d},
    "FULL_DESC" => lambda {|o,d| o.full_description = d},
    "SPC_RATES" => lambda {|o,d| o.special_rates = d},
    "SR1" => lambda {|o,d| o.special_rates = d},
    "UNITCODE" => lambda {|o,d| o.unit_of_measure = d},
    "GENERAL" => lambda {|o,d| o.general_rate = d},
    "GENERAL_RATE" => lambda {|o,d| o.general_rate = d},
    "GR1" => lambda {|o,d| o.general_rate = d},
    "CHAPTER" => lambda {|o,d| o.chapter = d},
    "HEADING" => lambda {|o,d| o.heading = d},
    "SUBHEADING" => lambda {|o,d| o.sub_heading = d},
    "REST_DESC" => lambda {|o,d| o.remaining_description = d},
    "ADDVALOREMRATE" => lambda {|o,d| o.add_valorem_rate = d},
    "PERUNIT" => lambda {|o,d| o.per_unit_rate = d},
    "MFN" => lambda {|o,d| o.most_favored_nation_rate = d},
    "GPT" => lambda {|o,d| o.general_preferential_tariff_rate = d},
    "ERGA_OMNES" => lambda {|o,d| o.erga_omnes_rate = d},
    "COL2_RATE" => lambda {|o,d| o.column_2_rate = d},
    "RATE2" => lambda {|o,d| o.column_2_rate = d},
    "Import Reg 1" => IMPORT_REG_LAMBDA,
    "Import Reg 2" => IMPORT_REG_LAMBDA,
    "Import Reg 3" => IMPORT_REG_LAMBDA,
    "Import Reg 4" => IMPORT_REG_LAMBDA,
    "Export Reg 1" => EXPORT_REG_LAMBDA,
    "Export Reg 2" => EXPORT_REG_LAMBDA,
    "Export Reg 3" => EXPORT_REG_LAMBDA,
    "Export Reg 4" => EXPORT_REG_LAMBDA,
#ignored fields
    "CALCULATIONMETHOD" => lambda {|o,d|}
  }

  def initialize(country,file_path)
    @country = country
    @file_path = file_path  
  end
  
  def process
    #clear existing
    OfficialTariff.transaction do
      puts "Deleting tariffs for #{@country.name}"
      OfficialTariff.where(:country_id=>@country).destroy_all
      #load new
      i = 0
      parser = get_parser
      parser.foreach(@file_path) do |row|
        headers = parser.headers
#headers.each {|h| raise "Column #{h} cannot be identified." if FIELD_MAP[h].nil?}
        ot = OfficialTariff.new(:country=>@country)
        FIELD_MAP.each do |header,lmda|
          col_num = headers.index header
          unless col_num.nil?
            val = row[col_num]
            lmda.call ot, (val.respond_to?('strip') ? val.strip : val)
          end
        end
        ot.save!
        puts "Processed line #{i} for country: #{@country.name}" if i>50 && i%50==0
        i += 1
      end
      puts "Re-linking tariffs for #{@country.name}"
      OfficialQuota.relink_country @country 
    end
  end

  def self.process_folder folder_path
    Dir.foreach(folder_path) do |entry|
      file_path = "#{folder_path}/#{entry}"
      if File.file? file_path
        c = Country.where(:iso_code => entry[0,2].upcase).first
        raise "Country not found with ISO #{entry[0,2]} for file #{entry}" if c.nil?
        TariffLoader.new(c,file_path).process
      end
    end
  end

  def get_parser 
    @file_path.downcase.end_with?("xls") ? XlsParser.new : CsvParser.new
  end

  class CsvParser

    def headers
      raise "Headers not initialized (a row must be read first)" unless @headers
      @headers
    end

    def foreach file_path, &block
      CSV.foreach(file_path, {:headers=>true}) do |row|
        @headers = row.headers unless @headers
        yield row
      end
    end

  end

  class XlsParser

    def headers
      raise "Headers not initialzied (a row must be read first)" unless @headers
      @headers
    end

    def foreach file_path, &block
      sheet = Spreadsheet.open(file_path).worksheet 0
      @headers = sheet.row 0
      sheet.each 1 do |row|
        yield row
      end
    end

  end
end
