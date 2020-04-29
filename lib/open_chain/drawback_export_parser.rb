require 'zip'
require 'open_chain/s3'

module OpenChain
  class DrawbackExportParser

    def self.parse_file file, importer
      case File.extname(file).downcase
      when ".zip"
        parse_zip_file(file, importer)
      when ".xls", ".xlsx"
        parse_local_xls(file, importer)
      when ".csv", ".txt"
        parse_csv_file(file.path, importer)
      else
        raise ArgumentError, "File extension not recognized"
      end
    end

    def self.parse_csv_file file_path, importer
      count = 0
      f = File.new(file_path)
      f.each_line do |line|
        unless count == 0
          ln = line.encode(Encoding.find("US-ASCII"), :undef=>:replace, :invalid=>:replace, :replace=>' ', :fallback=>' ')
          CSV.parse(ln, col_sep:csv_column_separator(ln)) do |r|
            d = parse_csv_line r, count, importer
            d.save! unless d.nil?
          end
        end
        count += 1
      end
    end

    def self.parse_xlsx_file s3_bucket, s3_path, importer
      count = 0
      f = xl_client(s3_bucket, s3_path)
      f.all_row_values do |line|
        unless count == 0
          line.map! {|element| element.to_s}
          d = parse_csv_line line, count, importer
          d.save! unless d.nil?
        end
        count += 1
      end
    end

    def self.parse_zip_file file, importer
      Zip::File.open(file.path) do |zipfile|
        zipfile.each do |entry|
          filename = entry.name
          base = File.basename(filename, ".*")
          extension = File.extname(filename)

          Tempfile.open([base, extension]) do |tempfile|
            tempfile.binmode
            tempfile.write entry.get_input_stream.read
            parse_file(tempfile, importer)
          end
        end
      end
    end

    def self.parse_local_xls file, importer
      OpenChain::S3.with_s3_tempfile(file) do |upload_response|
        parse_xlsx_file(upload_response.bucket, upload_response.key, importer)
      end
    end

    def self.xl_client bucket, path
      OpenChain::XLClient.new(path, bucket: bucket)
    end

    def self.csv_column_separator line
      ','
    end

  end
end
