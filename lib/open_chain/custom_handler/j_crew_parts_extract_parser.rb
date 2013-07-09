require 'csv'
require 'tempfile'
require 'open_chain/ftp_file_support'

module OpenChain
  module CustomHandler
    class JCrewPartsExtractParser
      include OpenChain::FtpFileSupport
      include AllianceProductSupport
      
      J_CREW_CUSTOMER_NUMBER ||= "J0000"
      JCrewProduct = Struct.new(:po, :article, :hts, :description, :country_of_origin, :season, :cost)
      COLUMN_HEADERS ||= Set.new ['PO #', 'Season', 'Article', 'HS #', 'Quota', 'Duty %', 'COO', 'FOB', 'PO Cost', 'Binding Ruling']

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
          ftp_file(temp, false)
          # Not a typo, we need to send the same file multiple times in order to send into 
          # each JCrew account (each time its sent it gets a different name - see remote_file_name)
          ftp_file(temp)
        end
      end

      def remote_file_name
        # Required for AllianceProductSupport for sending the file via FTP
        # Since we need to send multiple copies of the same file via FTP (one into each JCrew account)
        # We'll just name the first file as the first account name, and then the second as JCREW.DAT
        # and track the # of times the file has been FTP'ed.
        filename = "JCREW.DAT"
        if !@file_sent
          filename = "#{J_CREW_CUSTOMER_NUMBER}.DAT"
          @file_sent = true
        end  
        
        filename
      end

      # Reads the IO object containing JCrew part information and writes the translated output
      # data to the output_io stream.
      def generate_product_file input_io, output_io
        product = nil

        j_crew_company = Company.where("alliance_customer_number = ? ", J_CREW_CUSTOMER_NUMBER).first

        unless j_crew_company
          raise "Unable to process J Crew Parts Extract file because no company record could be found with Alliance Customer number '#{J_CREW_CUSTOMER_NUMBER}'."
        end

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
                write_product_data output_io, product, j_crew_company
                product = nil
              end

              product = parse_product_data line, JCrewProduct.new

            elsif !product.nil? && has_description(line)
              product.description = get_data(line, 5)
              write_product_data output_io, product, j_crew_company
              product = nil
            end
          end
        rescue
          # Re-raise the error but add approximately where we were in processing the file when the error occurred
          raise $!, "#{$!.message} occurred when reading a line at or close to line #{csv.lineno + 1}", $!.backtrace
        end

        write_product_data(output_io, product, j_crew_company) unless product.nil?
        output_io.flush
        nil
      end

      private 
        def write_product_data io, product, company
          # There's a couple of translations / validations we need to make to the data before writing it

          #Blank out invalid countries
          if product.country_of_origin.length != 2
            product.country_of_origin = ""
          end

          # Blank out invalid HTS numbers
          if product.hts.length != 10
            product.hts = ""
          end

          # J Crew has some out of date HTS #'s they send us which we automatically then translate into 
          # updated numbers.  Take care of this here.
          translated_hts = translate_hts_number product.hts, company

          io << "#{out(product.po, 20)}#{out(product.season, 10)}#{out(product.article, 30)}#{out(translated_hts, 10)} #{out(product.description, 40)} #{out(product.cost, 10)}#{out(product.country_of_origin, 2)}\r\n"
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
          product.hts = get_data(line, 6).gsub(".", "")
          product.country_of_origin = get_data line, 10
          product.cost = sprintf("%0.2f", BigDecimal.new(get_data(line, 12)))

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

        def translate_hts_number number, company
          translated = HtsTranslation.translate_hts_number number, "US", company

          return translated.blank? ? number : translated
        end
    end
  end
end