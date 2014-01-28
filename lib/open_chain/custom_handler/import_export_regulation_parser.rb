module OpenChain 
  module CustomHandler
    class ImportExportRegulationParser

      IMPORT_EXPORT_CONFIGURATIONS ||= {
        'TW' => {'.xls' => {:hts_number => 0, :import_regulations => 9, :export_regulations => 10},
                  '.txt' => {:hts_number => 0..11, :import_regulations => 113..152, :export_regulations => 154..193}}
      }

      def initialize country
        @country = country
      end

      def process io, file_name = nil
        parser = find_parser(io, file_name)
        OfficialTariff.transaction do
          parser.each_hts(io) do |hts_data|
            # The parser's sole job is to iterate through the IO data and pull data out of it, so we do need to make sure the file's
            # data looks ok here
            if valid_hts_line hts_data[:hts_number]

              # We do need to look up every hts number even if there's no import/export reg in the file, since it's possible we'll have to remove regulations
              tariff = OfficialTariff.where(:country_id => @country.id, :hts_code => hts_data[:hts_number]).first
              if tariff
                tariff.export_regulations = hts_data[:export_regulations]
                tariff.import_regulations = hts_data[:import_regulations]
                tariff.save!
              end
            end
          end
        end
      end

      def self.process_file io, iso_country_code, file_name = nil
        country = Country.where(:iso_code => iso_country_code).first
        raise "#{iso_country_code} is invalid." unless country
        ImportExportRegulationParser.new(country).process io, file_name
      end

      def self.process_s3 s3_key, iso_country_code
        S3.download_to_tempfile S3.bucket_name, s3_key do |t|
           process_file t, iso_country_code, File.basename(s3_key)
        end
      end

      class FixedWidthRegulationsParser
        def initialize field_ranges
          @field_ranges = field_ranges
        end

        def each_hts io
          io.each_line {|line|
            line = line.chomp

            yield hts_number: get_value(line, :hts_number), export_regulations: get_value(line, :export_regulations), import_regulations: get_value(line, :import_regulations)
          }
        end

        def get_value line, field
          value = line[@field_ranges[field]]
          value.nil? ? "" : value.strip
        end
      end

      class XlsRegulationsParser
        def initialize column_definitions
          @column_definitions = column_definitions
        end

        def each_hts io
          sheet = Spreadsheet.open(io).worksheet 0
          (0..sheet.last_row_index).each do |row_number|
            line = sheet.row(row_number)

            yield hts_number: get_value(line, :hts_number), export_regulations: get_value(line, :export_regulations), import_regulations: get_value(line, :import_regulations)
          end
        end

        def get_value line, field
          value = line[@column_definitions[field]]
          value.nil? ? "" : value.strip
        end
      end

      private 

        def find_parser io, filename = nil
          file_extension = nil
          if filename 
            file_extension = File.extname(filename)
          end

          file_extension = File.extname(io.path) if io.respond_to?(:path) && file_extension.blank?

          config = IMPORT_EXPORT_CONFIGURATIONS[@country.iso_code.upcase]

          parser = nil
          if config
            format_config = config[file_extension]

            if format_config
              case file_extension.downcase
              when '.txt'
                parser = FixedWidthRegulationsParser.new format_config
              when '.xls'
                parser = XlsRegulationsParser.new format_config
              end
            end
          end

          raise "The Import/Export Regulation Parser is not capable of processing #{file_extension} files for '#{@country.iso_code}'." unless parser
          parser
        end

        def valid_hts_line hts_number
          # We'll consider a valid HTS number being at least 6 digits long (ignoring any leading or trailing whitespace)
          hts_number && hts_number =~ /\s*\d{6,}\s*/
        end

    end
  end
end