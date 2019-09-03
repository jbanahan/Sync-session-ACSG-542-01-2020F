require 'csv'
require 'open_chain/custom_handler/vfitrack_custom_definition_support'

module OpenChain
  module CustomHandler
    class JCrewPartsExtractParser
      include VfitrackCustomDefinitionSupport
      
      J_CREW_CUSTOMER_NUMBER ||= "JCREW"
      
      def self.process_file path, file_name
        # The file coming to us is in utf-16le (weird), we'll transcode it below to UTF-8 so as to better work with it
        # internally.
        File.open(path, "r:utf-16le") do |io|
          JCrewPartsExtractParser.new.create_parts io, file_name
        end
      end

      # downloads the custom file to a temp file, then generate and send it
      def self.process_s3 s3_path, bucket = OpenChain::S3.bucket_name
        # Because download_to_tempfile sets the IO object to binmode, we can't use the
        # IO object directly, we can read from it via the path though.
        OpenChain::S3.download_to_tempfile(bucket, s3_path) do |file|
          process_file file.path, File.basename(s3_path)
        end
      end

      def initialize custom_file = nil
        @custom_file = custom_file
        @integration_user = User.integration
      end

      def custom_file
        @custom_file
      end

      def integration_user
        @integration_user
      end

      def can_view?(user)
        user.company.master?
      end

      # Required for usage via Custom File interfaces
      def process user
        if custom_file && custom_file.attached && custom_file.attached.path
          # custom files are always in the production bucket (even not on production systems)
          JCrewPartsExtractParser.process_s3 custom_file.attached.path, OpenChain::S3.bucket_name(:production)

          user.messages.create(:subject=>"J Crew Parts Extract File Complete",
            :body=>"J Crew Parts Extract File '#{custom_file.attached_file_name}' has finished processing.")
        end
      end


      # Reads the IO object containing JCrew part information and writes the translated output
      # data to the output_io stream.
      def create_parts io, file_name
        j_crew_company = Company.with_customs_management_number(J_CREW_CUSTOMER_NUMBER).first

        unless j_crew_company
          raise "Unable to process J Crew Parts Extract file because no company record could be found with Alliance Customer number '#{J_CREW_CUSTOMER_NUMBER}'."
        end

        product = nil
        line_number = 1
        begin
          io.each_line("\r\n") do |line|
            line = line.encode("UTF-8", undef: :replace, invalid: :replace, replace: "?")
            line.strip!

            if product.nil?
              if line =~ /^\d+/
                product = {}
                product[:po] = parse_data line[0,18]
                product[:season] = parse_data line[18, 14]
                product[:article] = parse_data line[32, 15]
                product[:hts] = parse_data line[47, 25]
                product[:cost] = parse_data line[134, 20]
              end
            else
              # This is a description line since we have an open product (always a description after a product line)
              product[:description] = parse_data line.strip
              save_product(product, j_crew_company, integration_user, file_name)
              product = nil
            end

            line_number+=1
          end

          nil
        rescue => e
          raise e, "#{e.message} occurred when reading a line at or close to line #{line_number}.", e.backtrace
        end
      end

      private

        def save_product product, importer, user, file_name
          uid = "JCREW-#{product[:article]}"
          p = nil
          Lock.acquire("Product-#{uid}") do
            p = Product.where(importer_id: importer.id, unique_identifier: uid).first_or_create!
          end

          Lock.db_lock(p) do
            changed = false
            p.name = product[:description]
            if p.custom_value(cdefs[:prod_part_number]) != product[:article]
              p.find_and_set_custom_value(cdefs[:prod_part_number], product[:article])
              changed = true
            end

            if p.hts_for_country(us).first != product[:hts]
              p.update_hts_for_country(us, product[:hts])
              changed = true
            end

            if p.changed? || changed
              p.save!
              p.create_snapshot user, nil, (custom_file.try(:attached_file_name) || file_name)
            end
          end
        end

        def us
          @country ||= Country.where(iso_code: "US").first
          raise "USA Country not found." if @country.nil?
          @country
        end

        def cdefs
          @cdefs ||= self.class.prep_custom_definitions([:prod_part_number, :prod_country_of_origin])
        end

        def parse_data d
          d.blank? ? "" : d.strip
        end

        def translate_hts_number number, company
          translated = HtsTranslation.translate_hts_number number, "US", company

          return translated.blank? ? number : translated
        end
    end
  end
end