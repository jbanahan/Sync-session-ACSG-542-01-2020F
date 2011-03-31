class CsvTariffLoader
  
  FIELD_MAP = {
    "HSCODE" => lambda {|o,d| o.hts_code = d},
    "FULL_DESC" => lambda {|o,d| o.full_description = d},
    "SPC_RATES" => lambda {|o,d| o.special_rates = d},
    "UNITCODE" => lambda {|o,d| o.unit_of_measure = d},
    "GENERAL" => lambda {|o,d| o.general_rate = d},
    "GENERAL_RATE" => lambda {|o,d| o.general_rate = d},
    "CHAPTER" => lambda {|o,d| o.chapter = d},
    "HEADING" => lambda {|o,d| o.heading = d},
    "SUBHEADING" => lambda {|o,d| o.sub_heading = d},
    "REST_DESC" => lambda {|o,d| o.remaining_description = d},
    "ADDVALOREMRATE" => lambda {|o,d| o.add_valorem_rate = d},
    "PERUNIT" => lambda {|o,d| o.per_unit_rate = d},
    "MFN" => lambda {|o,d| o.most_favored_nation_rate = d},
    "GPT" => lambda {|o,d| o.general_preferential_tariff_rate = d},
    "ERGA_OMNES" => lambda {|o,d| o.erga_omnes_rate = d},
    "COL2_RATE" => lambda {|o,d| o.column_2_rate = d}
  }

  def initialize(country,file_path)
    @country = country
    @file_path = file_path  
  end
  
  def process
    #clear existing
    puts "Deleting tariffs for #{@country.name}"
    OfficialTariff.where(:country_id=>@country).destroy_all
    #load new
    headers = nil
    i = 0
    CSV.foreach(@file_path, {:headers=>true}) do |row|
      headers = row.headers if headers.nil?
      ot = OfficialTariff.new(:country=>@country)
      FIELD_MAP.each do |header,lmda|
        col_num = headers.index header
        unless col_num.nil?
          lmda.call ot, row[col_num]
        end
      end
      ot.save!
      puts "Processed line #{i} for country: #{@country.name}" if i>50 && i%50==0
      i += 1
    end
  end

  def self.process_folder folder_path
    Dir.foreach(folder_path) do |entry|
      file_path = "#{folder_path}/#{entry}"
      if File.file? file_path
        c = Country.where(:iso_code => entry[0,2].upcase).first
        raise "Country not found with ISO #{entry[0,2]} for file #{entry}" if c.nil?
        CsvTariffLoader.new(c,file_path).process
      end
    end
  end
end
