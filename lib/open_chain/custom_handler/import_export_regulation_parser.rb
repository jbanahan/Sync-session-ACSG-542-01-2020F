module OpenChain 
  module CustomHandler
    class ImportExportRegulationParser

      IMPORT_EXPORT_COLUMN_RANGES = {
        'TW' => {:hts_number => 0..11, :import_regulations => 113..152, :export_regulations => 154..193}
      }

      def initialize country
        @country = country
        @field_ranges = IMPORT_EXPORT_COLUMN_RANGES[country.iso_code.upcase]
        raise "The Import/Export Regulation Parser is not capable of processing files for '#{country.iso_code}'." unless @field_ranges
      end

      def process io
        OfficialTariff.transaction do
          io.each_line { |line| 

            line = line.chomp
            hts = get_value line, :hts_number
            if valid_hts_line hts

              # We do need to look up every hts number even if there's no import/export reg in the file, since it's possible we'll have to remove regulations
              tariff = OfficialTariff.where(:country_id => @country.id, :hts_code => hts).first
              if tariff
                tariff.export_regulations = get_value line, :export_regulations
                tariff.import_regulations = get_value line, :import_regulations
                tariff.save!
              end
            end
          }
        end
      end

      def self.process_file io, iso_country_code
        # Technically, any old IO object should work here
        country = Country.where(:iso_code => iso_country_code).first
        raise "#{iso_country_code} is invalid." unless country
        ImportExportRegulationParser.new(country).process io
      end

      def self.process_s3 s3_key, iso_country_code
        S3.download_to_tempfile S3.bucket_name, s3_key do |t|
           process_file t, iso_country_code
        end
      end

      private 
        def valid_hts_line hts_number
          # We'll consider a valid HTS number being at least 6 digits long (ignoring any leading or trailing whitespace)
          hts_number && hts_number =~ /\s*\d{6,}\s*/
        end

        def get_value line, field
          value = line[@field_ranges[field]]
          value.nil? ? "" : value.strip
        end

    end
  end
end