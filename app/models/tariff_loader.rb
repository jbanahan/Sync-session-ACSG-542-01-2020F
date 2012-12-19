require 'zip/zip'

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
  MIN_VALID_COLUMN_LENGTH = 14

  def initialize(country,file_path,tariff_set_label)
    @country = country
    @file_path = file_path  
    @tariff_set_label = tariff_set_label
  end
  
  def process
    ts = nil
    # The first array index should be the file path and the second (if present) is a Tempfile pointing to the file we're processing
    tariff_file_info = get_file_to_process @file_path

    begin
      OfficialTariff.transaction do
        ts = TariffSet.create!(:country_id=>@country.id,:label=>@tariff_set_label)
        i = 0
        parser = get_parser tariff_file_info[0]
        parser.foreach(tariff_file_info[0]) do |row|
          headers = parser.headers
          ot = TariffSetRecord.new(:tariff_set_id=>ts.id,:country=>@country) #use .new instead of ts.tariff_set_records.build to avoid large in memory array
          FIELD_MAP.each do |header,lmda|
            col_num = headers.index header
            unless col_num.nil?
              lmda.call ot, TariffLoader.column_value(row[col_num])
            end
          end
          ot.save!
          puts "Processed line #{i} for country: #{@country.name}" if i>50 && i%50==0
          i += 1
        end
      end
    ensure
      #delete the tempfile we may be working with if the file we're processing was a zip file
      tariff_file_info[1].unlink unless (tariff_file_info[1].nil?() || !tariff_file_info[1].is_a?(Tempfile))
    end
    ts
  end

  def self.process_file file_path, tariff_set_label, auto_activate=false
    raise "#{file_path} is not a file." unless File.file? file_path
    c = Country.where(:iso_code => file_path.split('/').last[0,2].upcase).first
    raise "Country not found with ISO #{file_path.split('/').last[0,2].upcase} for file #{file_path}" if c.nil?
    ts = TariffLoader.new(c,file_path,tariff_set_label).process
    ts.activate if auto_activate
  end

  def self.process_s3 s3_key, country, tariff_set_label, auto_activate, user=nil
    Tempfile.open(['tariff_s3',".#{s3_key.split('.').last}"]) do |t|
      t.binmode
      s3 = AWS::S3.new AWS_CREDENTIALS
      t.write s3.buckets['chain-io'].objects[s3_key].read
      t.flush
      ts = TariffLoader.new(country,t.path,tariff_set_label).process
      ts.activate if auto_activate
      user.messages.create!(:subject=>"Tariff Set #{tariff_set_label} Loaded",:body=>"Tariff Set #{tariff_set_label} has been loaded and has #{auto_activate ? "" : "NOT"} been activated.") if user
    end
  end

  def self.column_value val 
    val.respond_to?('strip') ? val.strip : val
  end
  private

  def self.valid_header_row? row
    return false unless row.length >= MIN_VALID_COLUMN_LENGTH

    # See if we can find at least 1 of column header names in this row.  If we can,
    # we'll assume we're looking at the header row.
    FIELD_MAP.keys.each_with_index do |key, idx| 
      return true unless row.index(key).nil?
    end
    false
  end
  private

  def self.valid_row? row 
    # Do a basic check to make sure there's at least one column in the row.
    return false unless row.length >= MIN_VALID_COLUMN_LENGTH

    row.each do |v|
      # The to_s is there to handle cases where the cell's format is not text
      # thus allowing us to always use the length method regardless of data type
      # to determine if the cell has data in it
      return true if column_value(v).to_s.length > 0
    end
    false
  end
  private

  def get_parser file_path
    file_path.downcase.end_with?("xls") ? XlsParser.new : CsvParser.new    
  end

  def get_file_to_process file_path
    # [0] = the path to the file to process, the second index 
    # [1] = if a zip file, a tempfile reference to the extracted file.
    file_to_process = []
    if file_path.downcase.end_with? "zip"
      Zip::ZipFile.open(file_path) do |zip_file| 
        zip_file.each do |file|
            parser = get_parser(file.name)
            # Strip the extension from the file name for the first arg to the Tempfile constructor
            temp_output = Tempfile.new([File.basename(file.name, ".*"), File.extname(file.name)]) if file.file? && !parser.nil?
            if temp_output
              # Since the tempfile call above actually creates the file, force the overwrite
              # here (the extract call borks if you don't)
              zip_file.extract(file.name, temp_output.path) {true}
              file_to_process << temp_output.path
              file_to_process << temp_output
              break
            end
        end
      end
    else 
      file_to_process << file_path
    end
    file_to_process
  end
  private

  class CsvParser

    def headers
      raise "Headers not initialized (a row must be read first)" unless @headers
      @headers
    end

    def foreach file_path, &block
      CSV.foreach(file_path) do |row|
        # Iterate through the file until we find the header row
        if @headers 
          yield row if TariffLoader.valid_row? row
        else 
          @headers = row if TariffLoader.valid_header_row? row
        end
      end

      raise "No header row found in file #{File.basename(file_path)}." unless @headers
    end

  end

  class XlsParser

    def headers
      raise "Headers not initialzied (a row must be read first)" unless @headers
      @headers
    end

    def foreach file_path, &block
      sheet = Spreadsheet.open(file_path).worksheet 0
      header_index = -1
      #Find the first row of the spreadsheet that looks like it contains the worksheet headers
      sheet.each do |row|
        @headers = row if TariffLoader.valid_header_row? row
        header_index = row.idx if @headers
        break if @headers
      end

      raise "No header row found in spreadsheet #{File.basename(file_path)}." unless @headers

      # Start processing tariff information on the line directly after the header row
      sheet.each header_index + 1 do |row|
        yield row if TariffLoader.valid_row? row
      end
    end

  end
end
