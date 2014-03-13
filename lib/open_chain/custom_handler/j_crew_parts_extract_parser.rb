require 'csv'
require 'tempfile'
require 'open_chain/ftp_file_support'

module OpenChain
  module CustomHandler
    class JCrewPartsExtractParser
      include OpenChain::FtpFileSupport
      include AllianceProductSupport
      
      J_CREW_CUSTOMER_NUMBER ||= "J0000"
      
      def self.process_file path
        # The file coming to us is in Windows extended ASCII, tranlsate it to UTF-8 internally and when we 
        # output the file we're going to transliterate the data to ASCII for Alliance
        File.open(path, "r:Windows-1252:UTF-8") do |io|
          JCrewPartsExtractParser.new.generate_and_send io
        end
      end

      # downloads the custom file to a temp file, then generate and send it
      def self.process_s3 s3_path, bucket = OpenChain::S3.bucket_name
        # Because download_to_tempfile sets the IO object to binmode, we can't use the
        # IO object directly, we can read from it via the path though.
        OpenChain::S3.download_to_tempfile(bucket, s3_path) do |file|
          process_file file.path
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
        temp = Tempfile.new ['JCrewPartsExtract', '.DAT']
        begin
          temp.binmode
          generate_product_file(input_io, temp)
          send_ftp temp
          # Not a typo, we need to send the same file multiple times in order to send into 
          # each JCrew account (each time its sent it gets a different name - see remote_file_name)
          send_ftp temp
        ensure
          temp.close! unless temp.closed?
        end
      end

      def remote_file_name
        # Required for AllianceProductSupport for sending the file via FTP
        # Since we need to send multiple copies of the same file via FTP (one into each JCrew account)
        # We'll just name the first file as the first account name, and then the second as JPART.DAT
        # and track the # of times the file has been FTP'ed
        filename = "JPART.DAT"
        if !@file_sent
          filename = "#{J_CREW_CUSTOMER_NUMBER}.DAT"
          @file_sent = true
        end  
        
        filename
      end

      # Reads the IO object containing JCrew part information and writes the translated output
      # data to the output_io stream.
      def generate_product_file io, out
        j_crew_company = Company.where("alliance_customer_number = ? ", J_CREW_CUSTOMER_NUMBER).first

        unless j_crew_company
          raise "Unable to process J Crew Parts Extract file because no company record could be found with Alliance Customer number '#{J_CREW_CUSTOMER_NUMBER}'."
        end

        product = nil
        line_number = 1
        begin
          io.each_line("\r\n") do |line|
            line.strip!
            
            if product.nil?
              if line =~ /^\d+/
                product = {}
                product[:po] = parse_data line[0,18]
                product[:season] = parse_data line[18, 14]
                product[:article] = parse_data line[32, 15]
                product[:hts] = parse_data line[47, 25]
                product[:coo] = parse_data line[110, 11]
                product[:cost] = parse_data line[134, 20]
              end
            else
              # This is a description line since we have an open product (always a description after a product line)
              product[:description] = parse_data line.strip
              out << create_product_line(product, j_crew_company)
              product = nil
            end

            line_number+=1
          end

          out.flush
          nil
        rescue => e
          raise e, "#{e.message} occurred when reading a line at or close to line #{line_number}.", e.backtrace
        end
      end

      private 

        def out value, maxlen
          value = "" if value.nil?
          value = ActiveSupport::Inflector.transliterate(value)
          if value.length < maxlen
            value = value.ljust(maxlen)
          elsif value.length > maxlen
            value = value[0, maxlen]
          end
          
          value
        end

        def create_product_line product, company
          # Blank out invalid countries
          if product[:coo].length != 2
            product[:coo] = ""
          end

          # Blank out invalid HTS numbers
          if product[:hts].length != 10
            product[:hts] = ""
          end

          # J Crew has some out of date HTS #'s they send us which we automatically then translate into 
          # updated numbers.  Take care of this here.
          translated_hts = translate_hts_number product[:hts], company

          "#{out(product[:po], 20)}#{out(product[:season], 10)}#{out(product[:article], 30)}#{out(translated_hts, 10)} #{out(product[:description], 40)} #{out(product[:cost], 10)}#{out(product[:coo], 2)}\r\n"
        end

        def parse_data d
          d.blank? ? "" : d.strip
        end

        def translate_hts_number number, company
          translated = HtsTranslation.translate_hts_number number, "US", company

          return translated.blank? ? number : translated
        end

        def send_ftp temp
          # ftp send closes any stream we pass it here, which causes issues when trying to send the 
          # same stream twice..so just use a new file object instead.
          send = File.open temp.path, "rb"
          begin
            # Don't delete the tempfile, we have to send twice.
            ftp_file(send, false) 
          ensure 
            send.close unless send.closed?
          end
        end
    end
  end
end