require 'open_chain/xl_client'
require 'open_chain/s3'
require 'open_chain/custom_handler/csv_excel_parser'

module OpenChain; module CustomHandler; module CustomFileCsvExcelParser
  extend ActiveSupport::Concern
  include OpenChain::CustomHandler::CsvExcelParser

  class NoFileReaderError < StandardError; end

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
      raise NoFileReaderError, "No file reader exists for '#{File.extname(custom_file.path).downcase}' file types."
    end
  end

  # Convenience method for any extending classes that wish to get to a lower
  # level of access and use the reader directly.
  def excel_reader file, options = {}
    CustomFileExcelReader.new(file, options)
  end

  def csv_reader file, options = {}
    CustomFileCsvReader.new(file, options)
  end

  class CustomFileCsvReader

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

  class CustomFileExcelReader

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
      @xl_client.all_row_values(sheet_number: sheet_number) do |row|
        yield row
      end
      nil
    end

    def get_xl_client path, opts
      OpenChain::XLClient.new(path, opts)
    end
  end

end; end; end