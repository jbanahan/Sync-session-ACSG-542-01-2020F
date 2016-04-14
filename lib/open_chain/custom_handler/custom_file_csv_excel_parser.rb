require 'open_chain/xl_client'
require 'open_chain/s3'

module OpenChain; module CustomHandler; module CustomFileCsvExcelParser
  extend ActiveSupport::Concern

  def foreach custom_file, skip_headers:false, skip_blank_lines:false
    reader = file_reader(custom_file)
    rows = block_given? ? nil : []
    headers = false
    row_number = -1
    reader.foreach do |row|
      row_number += 1
      if skip_headers && !headers
        headers = true
        next
      end

      next if skip_blank_lines && blank_row?(row)

      if rows
        rows << row
      else
        yield row, row_number
      end
    end

    rows
  end

  # Returns false if any any non-blank value is found in the row
  def blank_row? row
    return true if row.blank?
    row.each {|v| return false unless v.blank?}
    return true
  end

  def date_value value
    date = nil
    if value.is_a? String
      #Convert any / to a hypehn
      value = value.gsub('/', '-').strip
      # Try yyyy-mm-dd then mm-dd-yyyy then mm-dd-yy
      date = parse_and_validate_date(value, "%Y-%m-%d")
      unless date
        if value.split("-")[2].try(:length) == 4
          date = parse_and_validate_date(value, "%m-%d-%Y")
        else
          date = parse_and_validate_date(value, "%m-%d-%y")
        end
      end
    elsif value.acts_like?(:date) || value.acts_like?(:time)
      date = value.to_date
    end

    date
  end

  def parse_and_validate_date date, format
    # by default, validate the date is within 2 years from today
    parsed_date = Date.strptime(date, format) rescue nil
    if parsed_date
      parsed_date = nil if (parsed_date.year - Time.zone.now.year).abs > 2
    end
    parsed_date
  end

  def text_value value
    OpenChain::XLClient.string_value value
  end

  def decimal_value value, decimal_places: nil
    # use space character set since that handles all UTF-8 whitespace too, not just ascii 33 (space bar)
    v = BigDecimal(value.to_s.gsub(/\$[[:space:]]/, ""))
    # Round to t decimal places
    if decimal_places.to_i > 0
      v = v.round(decimal_places, BigDecimal::ROUND_HALF_UP)
    end
    v
  end

  def file_reader custom_file
    case File.extname(custom_file.path).downcase
    when ".csv", ".txt"
      options = {}
      if respond_to?(:csv_reader_options)
        options = csv_reader_options.with_indifferent_access
      end
      csv_reader custom_file, options
    when ".xls", ".xlsx"
      options = {}
      if respond_to?(:excel_reader_options)
        options = excel_reader_options.with_indifferent_access
      end
      excel_reader custom_file, options
    else
      raise "No file reader exists for #{File.extname(custom_file.path).downcase} file types."
    end

  end

  # Convenience method for any extending classes that wish to get to a lower
  # level of access and use the reader directly.
  def excel_reader custom_file, options = {}
    ExcelReader.new(custom_file, options)
  end

  def csv_reader custom_file, options = {}
    CsvReader.new(custom_file, options)
  end

  class CsvReader

    attr_reader :reader_options

    def initialize custom_file, reader_options
      @custom_file = custom_file
      @reader_options = reader_options
    end

    def foreach
      OpenChain::S3.download_to_tempfile(@custom_file.bucket, @custom_file.path) do |file|
        # CSV doesn't like hashes that have any string keys....it dislikes them so much
        # that it blows up.  So just symbolize them
        CSV.foreach(file, @reader_options.symbolize_keys) do |row|
          yield row
        end
      end
      nil
    end
  end

  class ExcelReader

    attr_reader :reader_options, :xl_client

    def initialize custom_file, reader_options
      @custom_file = custom_file
      @reader_options = reader_options
    end

    def foreach 
      sheet_number = @reader_options.delete :sheet_number
      sheet_number = 0 unless sheet_number

      # Make sure bucket always comes from the custom file, not based on the xl client default
      opts = {bucket: @custom_file.bucket}.merge @reader_options
      @xl_client = get_xl_client(@custom_file.path, opts)
      @xl_client.all_row_values(sheet_number) do |row|
        yield row
      end
      nil
    end

    def get_xl_client path, opts
      OpenChain::XLClient.new(path, opts)
    end
  end

end; end; end