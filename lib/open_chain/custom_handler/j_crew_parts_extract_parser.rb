require 'csv'
require 'tempfile'
require 'open_chain/ftp_file_support'

module OpenChain
  module CustomHandler
    class JCrewPartsExtractParser
      include OpenChain::FtpFileSupport
      include AllianceProductSupport
      
      JCrewProduct = Struct.new(:po, :article, :hts, :description, :country_of_origin, :season, :cost)
      COLUMN_HEADERS = Set.new ['PO #', 'Season', 'Article', 'HS #', 'Quota', 'Duty %', 'COO', 'FOB', 'PO Cost', 'Binding Ruling']
      HTS_TRANSLATIONS = {
        '4602102500' => '4202192500', \
        '6115110010' => '6115210010', \
        '6115122000' => '6115220000', \
        '6203424005' => '6203424006', \
        '6203424010' => '6203424011', \
        '6203424015' => '6203424016', \
        '6203424025' => '6203424026', \
        '6203424045' => '6203424046', \
        '6203424050' => '6203424051', \
        '6203424060' => '6203424061', \
        '6204624005' => '6204624006', \
        '6204624020' => '6204624021', \
        '6204624030' => '6204624031', \
        '6204624050' => '6204624051', \
        '6204624055' => '6204624056', \
        '6204624065' => '6204624066', \
        '6205202050' => '6205202051', \
        '6205202060' => '6205202061', \
        '6205202065' => '6205202066', \
        '6206303010' => '6206303011', \
        '6206303030' => '6206303031', \
        '6206303040' => '6206303041', \
        '6211310040' => '6211320040', \
        '6404193560' => '6404193960', \
        '6505906040' => '6505006040', \
        '6505908090' => '6505008090', \
        '6505902060' => '6506002060', \
        '6601900000' => '6601910000'}

      def self.process_file path
        # Open in binmode (otherwise we tend to run into encoding issues with this file)
        File.open(path, "rb") do |io|
          JCrewPartsExtractParser.new.generate_and_send io
        end
      end

      # downloads the custom file to a temp file, then generate and send it
      def self.process_s3 s3_path, bucket = OpenChain::S3.bucket_name
        OpenChain::S3.download_to_tempfile(bucket, s3_path) do |file|
          JCrewPartsExtractParser.new.generate_and_send file
        end
      end

      def initialize custom_file = nil
        @custom_file = custom_file
      end

      def can_view?(user)
        user.company.master?
      end

      # Required for usage via Custom File interfaces
      def process user
        if @custom_file && @custom_file.attached && @custom_file.attached.path
          # custom files are always in the production bucket (even not on production systems)
          JCrewPartsExtractParser.process_s3 @custom_file.attached.path, OpenChain::S3.bucket_name(:production)

          user.messages.create(:subject=>"J Crew Parts Extract File Complete",
            :body=>"J Crew Parts Extract File '#{@custom_file.attached_file_name}' has finished processing.")
        end
      end

      def generate_and_send input_io
        # ftp_file is from FtpSupport
        # All ftp options for FTP sending are defined in AllianceProductSupport (except remote_file_name)
        Tempfile.open(['JCrewPartsExtract', '.DAT']) do |temp|
          temp.binmode
          generate_product_file(input_io, temp)
          ftp_file(temp)
        end
      end

      def remote_file_name
        # Required for AllianceProductSupport for sending the file via FTP
        "#{Time.now.to_i}-J0000.DAT"
      end

      def ftp_file file, delete_local=true
        require 'fileutils'
        FileUtils.cp(file.path, "tmp/#{remote_file_name}")
        file.unlink if delete_local
      end

      # Reads the IO object containing JCrew part information and writes the translated output
      # data to the output_io stream.
      def generate_product_file input_io, output_io
        product = nil

        # While this file is named like .xls, it's not an excel file, it's a tab delimited file.
        # There is no quote handling or any of that in the file (since it's tab delimited presumably there's no need to)
        # Unfortunately, ruby doesn't really have a way to turn off quoting, and this file has " marks in it all over the place
        # The easiest way I can think of to turn off quoting is to just tell it a character its never going to see is the quote char.
        # So I'm using the bell character (\007)
        csv = CSV.new(input_io, {:col_sep => "\t", :skip_blanks => true, :quote_char=> "\007"})
        begin
          csv.each do |line|
            if has_product_header_data(line)
              # Just in case we get a product without a description and then another line, write the product
              # data sans description in that case.
              if !product.nil?
                write_product_data output_io, product
                product = nil
              end

              product = parse_product_data line, JCrewProduct.new

            elsif !product.nil? && has_description(line)
              product.description = get_data(line, 5)
              write_product_data output_io, product
              product = nil
            end
          end
        rescue
          # Re-raise the error but add approximately where we were in processing the file when the error occurred
          raise $!, "#{$!.message} occurred when reading a line at or close to line #{csv.lineno + 1}", $!.backtrace
        end

        write_product_data(output_io, product) unless product.nil?
        output_io.flush
        nil
      end

      private 
        def write_product_data io, product
          # There's a couple of translations / validations we need to make to the data before writing it

          #Blank out invalid countries
          if product.country_of_origin.length != 2
            product.country_of_origin = ""
          end

          # Blank out invalid HTS numbers
          if product.hts.length != 10
            product.hts = ""
          end

          # TODO Add the HTS translation here using the xref table for JCrew and US country.
          if HTS_TRANSLATIONS.has_key?(product.hts)
            product.hts = HTS_TRANSLATIONS[product.hts]
          end

          #io << "#{out(product.po, 20)}#{out(product.article, 30)}#{out(product.hts, 10)}#{out(product.description, 40)}#{out(product.country_of_origin, 2)}\r\n"
          io << "#{out(product.po, 20)}#{out(product.season, 10)}#{out(product.article, 30)}#{out(product.hts, 10)} #{out(product.description, 40)} #{out(product.cost, 10)}#{out(product.country_of_origin, 2)}\r\n"
        end

        def out value, maxlen
          value = "" if value.nil?
          if value.length < maxlen
            value = value.ljust(maxlen)
          elsif value.length > maxlen
            value = value[0, maxlen]
          end
          
          value
        end

        def parse_product_data line, product
          product.po = get_data line, 1
          product.season = get_data line, 4
          product.article = get_data line, 5
          product.hts = get_data line, 6
          product.country_of_origin = get_data line, 9
          product.cost = sprintf("%0.2f", BigDecimal.new(get_data(line, 11)))

          product
        end

        def get_data line, column
          data = line[column]

          return data.nil? ? "" : data.strip
        end

        def has_product_header_data line
          # We're looking for at least 12 columns of data with column 1 and 5 having data in them AND
          # none of the columns containing any header names.
          return line.length >= 12 && has_data(line, 1) && has_data(line, 5) && has_no_column_headers(line)
        end

        def has_data line, column
          return !(line[column].blank? || line[column].strip.length == 0)
        end

        def has_no_column_headers line
          line.each do |col|
            return false if !col.nil? && COLUMN_HEADERS.include?(col.strip)
          end
          return true
        end

        def has_description line
          return has_data(line, 5)
        end
    end
  end
end