require 'open_chain/custom_handler/csv_excel_parser'
require 'open_chain/integration_client_parser'
require 'zip'

class TariffLoader
  include OpenChain::IntegrationClientParser
  include OpenChain::CustomHandler::CsvExcelParser

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

  ASSIGN_FDA_LAMBDA = lambda {|o,d|
    return unless d && d =~ /^(FD|fd)/
    if o.fda_indicator
      indicators = o.fda_indicator.split("\n ") << d.upcase
      o.fda_indicator = indicators.uniq.sort.join("\n ")
    else
      o.fda_indicator = d.upcase
    end
  }

  SUB_HEADING_LAMBDA = lambda {|o,d| o.sub_heading = d}
  UOM_HEADING_LAMBDA = lambda {|o,d| o.unit_of_measure = d}

  FIELD_MAP = {
    "HSCODE" => lambda {|o,d| o.hts_code = d},
    "FULL_DESC" => lambda {|o,d| o.full_description = d},
    "SPC_RATES" => lambda {|o,d| parse_spc_rates(o, d)},
    "SR1" => lambda {|o,d| o.special_rates = d},
    "UNITCODE" => UOM_HEADING_LAMBDA,
    "UOM" => UOM_HEADING_LAMBDA,
    "UOM1" => UOM_HEADING_LAMBDA,
    "GENERAL" => lambda {|o,d| o.general_rate = d},
    "GENERAL_RATE" => lambda {|o,d| o.general_rate = d},
    "GR1" => lambda {|o,d| o.general_rate = d},
    "CHAPTER" => lambda {|o,d| o.chapter = d},
    "HEADING" => lambda {|o,d| o.heading = d},
    "SUBHEADING" => SUB_HEADING_LAMBDA,
    "SUBHEAD" => SUB_HEADING_LAMBDA,
    "REST_DESC" => lambda {|o,d| o.remaining_description = d},
    "ADDVALOREMRATE" => lambda {|o,d| o.add_valorem_rate = d},
    "PERUNIT" => lambda {|o,d| o.per_unit_rate = d},
    "MFN" => lambda {|o,d| o.most_favored_nation_rate = d},
    "GPT" => lambda {|o,d| o.general_preferential_tariff_rate = d},
    "ERGA_OMNES" => lambda {|o,d| o.erga_omnes_rate = d},
    "COL2_RATE" => lambda {|o,d| o.column_2_rate = d},
    "RATE2" => lambda {|o,d| o.column_2_rate = d},
    "PGA_CD1" => ASSIGN_FDA_LAMBDA,
    "PGA_CD2" => ASSIGN_FDA_LAMBDA,
    "PGA_CD3" => ASSIGN_FDA_LAMBDA,
    "PGA_CD4" => ASSIGN_FDA_LAMBDA,
    "Import Reg 1" => IMPORT_REG_LAMBDA,
    "IMP_REG1" => IMPORT_REG_LAMBDA,
    "Import Reg 2" => IMPORT_REG_LAMBDA,
    "IMP_REG2" => IMPORT_REG_LAMBDA,
    "Import Reg 3" => IMPORT_REG_LAMBDA,
    "IMP_REG3" => IMPORT_REG_LAMBDA,
    "Import Reg 4" => IMPORT_REG_LAMBDA,
    "IMP_REG4" => IMPORT_REG_LAMBDA,
    "Export Reg 1" => EXPORT_REG_LAMBDA,
    "EXP_REG1" => EXPORT_REG_LAMBDA,
    "Export Reg 2" => EXPORT_REG_LAMBDA,
    "EXP_REG2" => EXPORT_REG_LAMBDA,
    "Export Reg 3" => EXPORT_REG_LAMBDA,
    "EXP_REG3" => EXPORT_REG_LAMBDA,
    "Export Reg 4" => EXPORT_REG_LAMBDA,
    "EXP_REG4" => EXPORT_REG_LAMBDA,
    #ignored fields
    "CALCULATIONMETHOD" => lambda {|o,d|}
  }
  MIN_VALID_COLUMN_LENGTH = 10

  # Enables some special MFN handling for these countries
  MOST_FAVORED_NATION_SPECIAL_PARSE_ISOS = ['CN']

  def initialize(country,file_path,tariff_set_label)
    @country = country
    @file_path = file_path  
    @tariff_set_label = tariff_set_label
    should_do_mfn_parse country
  end

  # TODO this method needs unit-testing
  def process
    ts = nil
    # The first array index should be the file path and the second (if present) is a Tempfile pointing to the file we're processing
    tariff_file, temp_file = get_file_to_process @file_path

    begin
      OfficialTariff.transaction do
        ts = TariffSet.create!(:country_id=>@country.id,:label=>@tariff_set_label)
        i = 0
        parser = get_parser tariff_file
        parser.foreach(tariff_file) do |row|
          headers = parser.headers
          ot = TariffSetRecord.new(:tariff_set_id=>ts.id,:country=>@country) #use .new instead of ts.tariff_set_records.build to avoid large in memory array
          FIELD_MAP.each do |header,lmda|
            col_num = headers.index header
            unless col_num.nil?
              instance_exec ot, TariffLoader.column_value(row[col_num]), &lmda
            end
          end
          ot.save!
          i += 1
        end
      end
    ensure
      #delete the tempfile we may be working with if the file we're processing was a zip file
      temp_file.close! unless temp_file.nil?
    end
    ts
  end

  # Files routed by TariffFileMonitor are processed using this method (via handle_processing).
  # It's assumed that it's getting a file path, not file content.
  def self.parse_file file_path, log, opts = {}
    file_name = file_path.split('/').last
    iso_code = file_name[0,2].upcase
    tariff_set_label = "#{iso_code}-#{Time.zone.now.strftime("%Y-%m-%d")}"

    c = Country.where(iso_code:iso_code).first
    log.error_and_raise "Country not found with ISO #{iso_code} for file #{file_name}" if c.nil?

    ts = TariffLoader.new(c, file_path, tariff_set_label).process
    # Files loaded this way are always activated.  (Really, the ones loaded via the old screen are always activated too.)
    ts.activate
  end

  def self.process_from_s3 bucket, key, opts={}
    OpenChain::S3.download_to_tempfile(bucket, key, original_filename: key) do |t|
      # Handle processing is provided a file path, not the actual file content.  Still, it's not 0-bytes, so it
      # bypasses that validation.
      handle_processing(bucket, key, opts) { t.path }
    end
  end

  def self.process_from_file file, opts={}
    # This File behavior is a little silly, but (a) it beats rewriting the entire processing apparatus here and
    # (b) typical usage for this method is to pass a path, making that silliness irrelevant.  This is just a
    # developer helper method.
    file_path = file.is_a?(File) ? file.path : file
    # Handle processing is provided a file path, not the actual file content.  Still, it's not 0-bytes, so it
    # bypasses that validation.
    handle_processing(nil, file_path, opts) { file_path }
  end

  # Manual upload via screen (tariff_sets) goes this route.  See TariffSetsController.
  def self.process_s3 s3_key, country, tariff_set_label, auto_activate, user=nil
    OpenChain::S3.download_to_tempfile("chain-io", s3_key, original_filename: s3_key) do |t|
      ts = TariffLoader.new(country,t.path,tariff_set_label).process
      ts.activate if auto_activate
      user.messages.create!(:subject=>"Tariff Set #{tariff_set_label} Loaded",:body=>"Tariff Set #{tariff_set_label} has been loaded and has#{auto_activate ? "" : " NOT"} been activated.") if user
    end
  end

  def self.column_value val 
    val.respond_to?('strip') ? val.strip : val
  end

  def self.valid_header_row? row
    return false unless row.length >= MIN_VALID_COLUMN_LENGTH

    # See if we can find at least 1 of column header names in this row.  If we can,
    # we'll assume we're looking at the header row.
    FIELD_MAP.keys.each_with_index do |key, idx| 
      return true unless row.index(key).nil?
    end
    false
  end

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

    def parse_spc_rates tariff, val
      tariff.special_rates = val

      # The following regex looks for a decimal value (optionally followed by a %) or words
      # followed by zero or one space, followed by a colon, followed by zero or one space
      # followed by an open parenth MFN (any chars) and then the first close parenth
      if @do_mfn_parse && val =~ /(\d+%?|\w+) ?: ?\(MFN.*?\)/
        tariff.most_favored_nation_rate = $1
        #tariff.common_rate = $1
      end
    end

    def get_parser file_path
      file_path.downcase.end_with?("xls") ? XlsParser.new : CsvParser.new
    end

    def get_file_to_process file_path
      # [0] = the path to the file to process, the second index
      # [1] = if a zip file, a tempfile reference to the extracted file.
      file_to_process = []
      if file_path.downcase.end_with? "zip"
        Zip::File.open(file_path) do |zip_file|
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

    def should_do_mfn_parse country
      @do_mfn_parse = MOST_FAVORED_NATION_SPECIAL_PARSE_ISOS.include? country.iso_code.upcase
    end

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
