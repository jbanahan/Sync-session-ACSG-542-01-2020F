require 'spreadsheet'

# This module provides simple row by row parsing of CSV or Excel files.
# The including class must implement a method named file_reader with a 
# method signature of "file_reader(file)" and return any object that
# responds to foreach by yielding "row" objects from the file.
#
# For convenience sake, an excel and csv based file reader is provided
# via the excel_reader and csv_reader methods.
#
# A simple implementation of "file_reader(file)" my look like this:
# 
#  def file_reader file
#     csv_reader(file)
#  end
#
# Once implementing the "file_reader" method the calling simply has to
# call the "foreach" method and be yield back successive rows from the file.
#
# Helper methods are also provided for handling of data type specific values
# like date_value, text_value, decimal_value.
module OpenChain; module CustomHandler; module CsvExcelParser
  extend ActiveSupport::Concern

  def foreach file, skip_headers:false, skip_blank_lines:false
    reader = file_reader(file)
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

  def date_value value, date_format: nil
    date = nil
    if value.is_a? String

      if date_format.nil?
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
      else
        # If we're providing an exact format, then there's no need to actually validate the date by
        # checking for "recent" dates
        date = Date.strptime(value, date_format) rescue nil
      end
    elsif value.acts_like?(:date) || value.acts_like?(:time)
      date = value.to_date
    end

    date
  end

  def integer_value value
    decimal_value(value).to_i
  end

  def parse_and_validate_date date, format
    # by default, validate the date is within 2 years from today
    parsed_date = Date.strptime(date, format) rescue nil
    if parsed_date && !MasterSetup.test_env?
      parsed_date = nil if (parsed_date.year - Time.zone.now.year).abs > max_valid_date_age_years
    end
    parsed_date
  end

  def max_valid_date_age_years
    2
  end

  def text_value value, strip_whitespace: true
    v = OpenChain::XLClient.string_value value
    if strip_whitespace
      v = v.nil? ? v : v.strip
    end

    v
  end

  def decimal_value value, decimal_places: nil
    # use space character set since that handles all UTF-8 whitespace too, not just ascii 33 (space bar)
    v = BigDecimal(value.to_s.gsub(/\$[[:space:]]/, "").gsub(",", "")) rescue BigDecimal(0)
    # Round to t decimal places
    if decimal_places.to_i > 0
      v = v.round(decimal_places, BigDecimal::ROUND_HALF_UP)
    end
    v
  end

  def boolean_value value
    if !value.nil? && value.to_s.length > 0
      dstr = value.to_s.downcase.strip
      if ["y", "yes","true", "1"].include?(dstr)
        return true
      elsif ["n", "no","false", "0"].include?(dstr)
        return false
      end
    end
    nil
  end

  # Convenience method for any extending classes that wish to get to a lower
  # level of access and use the reader directly, or redirect the reader that's
  # used.  Reader ONLY has to respond to foreach and yield rows from the file.
  def excel_reader file, options = {}
    LocalExcelReader.new(file, options)
  end

  def csv_reader file, options = {}
    LocalCsvReader.new(file, options)
  end

  class LocalCsvReader

    attr_reader :reader_options

    def initialize file, reader_options
      @file = file
      @reader_options = reader_options
    end

    def foreach
      # CSV doesn't like hashes that have any string keys....it dislikes them so much
      # that it blows up.  So just symbolize them
      parse_options = @reader_options.symbolize_keys
      if @file.respond_to?(:read)
        CSV.parse(@file, parse_options) do |row|
          yield row
        end
      else
        CSV.foreach(@file, parse_options) do |row|
          yield row
        end
      end
      
      nil
    end
  end
  

  class LocalExcelReader

    attr_reader :reader_options, :xl_client

    def initialize file, reader_options
      @file = file
      @reader_options = reader_options
    end

    def foreach 
      sheet_number = @reader_options.delete :sheet_number
      sheet_number = 0 unless sheet_number

      sheet = Spreadsheet.open(@file).worksheets[sheet_number]
      sheet.each do |row|
        yield row
      end

      nil
    end
  end

end; end; end
