require 'open_chain/fixed_position_generator'

module OpenChain
  module CustomHandler
    class FenixProductFileGenerator < OpenChain::FixedPositionGenerator
      include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport

      def initialize fenix_customer_code, options = {}
        super()
        @fenix_customer_code = fenix_customer_code
        @canada_id = Country.find_by_iso_code('CA').id
        @importer_id = options['importer_id']
        @use_part_number = (options['use_part_number'].to_s == "true")
        @additional_where = options['additional_where']
        @suppress_country = options['suppress_country']
        @suppress_description = (options['suppress_description'].to_s == "true")
        @output_subdirectory = (options['output_subdirectory'].presence || '')
        @strip_leading_zeros = (options['strip_leading_zeros'].to_s == "true")

        if MasterSetup.get.custom_feature? "Full Fenix Product File"
          custom_defintions = [:class_special_program_indicator, :class_cfia_requirement_id, :class_cfia_requirement_version, :class_cfia_requirement_code, :class_ogd_end_use, :class_ogd_misc_id, :class_ogd_origin, :class_sima_code]
        else
          custom_defintions = []
        end
        
        custom_defintions << :class_stale_classification
        custom_defintions << :prod_part_number if @use_part_number
        custom_defintions << :prod_country_of_origin unless @suppress_country
        custom_defintions << :class_customs_description unless @suppress_description
        
        @cdefs = self.class.prep_custom_definitions custom_defintions
      end

      #automatcially generate file and ftp for trading partner "fenix-#{fenix_customer_code}"
      def generate
        ftp_file make_file find_products 
      end

      def find_products
        r = Product.
          includes(:classifications=>:tariff_records).
          # Prevent stale classifications from going to Fenix
          joins("LEFT OUTER JOIN custom_values v on classifications.id = v.customizable_id AND v.customizable_type = 'Classification' AND custom_definition_id = #{@cdefs[:class_stale_classification].id}").
          where("v.boolean_value IS NULL OR v.boolean_value = 0").
          where("classifications.country_id = #{@canada_id} and length(tariff_records.hts_1) > 6").need_sync("fenix-#{@fenix_customer_code}")
        
        if @importer_id
          r = r.where(:importer_id => @importer_id)
        end

        if @additional_where
          r = r.where(@additional_where)
        end

        r
      end
      
      def make_file products, update_sync_records = true
        t = Tempfile.new(["fenix-#{@fenix_customer_code}",'.txt'])
        t.binmode
        user = User.integration
        products.each do |p|
          stale_classification = false
          c = p.classifications.find {|cl| cl.country_id == @canada_id }
          next unless c
          c.tariff_records.each do |tr|
            unless tr.hts_1.blank?

              if stale_classification? tr
                stale_classification = true
              else
                begin
                  # Fenix's database uses the windows extended "ASCII" encoding.  Make sure we transcode our UTF-8 data to the windows encoding
                  # This lets us send characters like ”, Æ, etc correctly to Fenix
                  t << file_output(@fenix_customer_code, p, c, tr).encode("WINDOWS-1252")
                rescue Encoding::UndefinedConversionError => e
                  e.log_me "Product #{p.unique_identifier} could not be sent to Fenix because it cannot be converted to Windows-1252 encoding."
                  next
                end
                break
              end
            end
          end

          if stale_classification
            update_stale_classification(user, p, c)
          else
            # If we need to manually generate a file, then we won't want to run the sync data
            if update_sync_records
              sr = p.sync_records.where(trading_partner: "fenix-#{@fenix_customer_code}").first_or_initialize
              sr.sent_at = Time.now
              sr.confirmed_at = 1.second.from_now
              sr.confirmation_file_name = "Fenix Confirmation"
              sr.save!
            end
          end

        end
        t.flush
        t
      end

      def stale_classification? t
        ids = OfficialTariff.where(country_id: @canada_id, hts_code: t.hts_1).limit(1).pluck :id
        return ids.blank?
      end

      def update_stale_classification user, product, classification
        classification.update_custom_value! @cdefs[:class_stale_classification], true
        product.create_snapshot user, nil, "Stale Tariff"
      end

      def ftp_file f
        folder = "to_ecs/fenix_products/#{@output_subdirectory}"
        FtpSender.send_file('ftp2.vandegriftinc.com','VFITRack','RL2VFftp',f,{:folder=>folder, :remote_file_name=>File.basename(f.path)})
        f.unlink
      end

      def self.run_schedulable opts_hash={}
        OpenChain::CustomHandler::FenixProductFileGenerator.new(opts_hash["fenix_customer_code"], opts_hash).generate
      end
      
      private
        def file_output fenix_customer_code, p, c, tr
          # For some reason the product line starts with an N followed by 14 blanks
          line = "N"
          line << str("", 14)
          line << str(fenix_customer_code, 9) # Client Code (15 - 24)
          line << str("", 7) # Blank Space (24, 31)
          line << str(identifier_field(p), 40) # Part Number (31 - 71)
          line << str(tr.hts_1, 20)  # Classification (71 - 91)
          line << str("", 4) # Tariff Code (91 - 95)
          line << str("", 20) # Keyword (95 - 115)
          line << str("", 20) # Blank Sapce (115 - 135)
          line << str((@suppress_description ? "" : custom_value(c, :class_customs_description).to_s), 50) # Description 1 (135 - 185)
          line << str("", 50) # Description 2 (185 - 235)
          line << str("", 16) # OIC Code (235 - 251)
          line << str("", 41) # Blank Space (251 - 292)
          line << str("", 3) # Sale UOM (292 - 295)
          line << str("", 32) # Blank Space (295 - 327)
          line << str("", 7) # GST Exemption Code (327 - 334)
          line << str("", 7) # Blank Space (334 - 341)
          spi = custom_value(c, :class_special_program_indicator)
          line << str(spi.blank? ? "" : spi.to_i, 2) # Tariff Treatment (341, 343)
          line << str("", 16) # Blank Space (343 - 359)
          line << str((@suppress_country ? "" : custom_value(p, :prod_country_of_origin).to_s), 3) # Country Of Origin (359 - 362)
          line << str(custom_value(c, :class_cfia_requirement_id), 8) # CFIA Requirement ID (362 - 370)
          line << str(custom_value(c, :class_cfia_requirement_version), 4) # CFIA Requirement Version (370 - 374)
          line << str(custom_value(c, :class_cfia_requirement_code), 6) # CFIA Code (374 - 380)
          line << str(custom_value(c, :class_ogd_end_use), 3) # OGD End Use (380 - 383)
          line << str(custom_value(c, :class_ogd_misc_id), 3) # OGD Misc Id (383 - 386)
          line << str(custom_value(c, :class_ogd_origin), 3) # OGD Origin (386 - 389)
          line << str(custom_value(c, :class_sima_code), 2) # SIMA Code (389 - 391)
          # line << str("", 2) # Excise Rate (391 - 393)

          #Because Canada doesn't allow exclamation marks in B3 files (WTF?, strip them
          line = line.gsub("!", " ") 
          line += "\r\n"
        end

        def force_fixed str, len
          return str.ljust(len) if str.length <= len
          str[0,len]
        end

        def identifier_field p
          value = nil
          if @use_part_number
            value = p.custom_value(@cdefs[:prod_part_number])
          else
            value = p.unique_identifier
          end
          @strip_leading_zeros ? value.to_s.gsub(/^0+/, "") : value
        end

        def custom_value obj, field
          # This is primarily here just because we don't allow all the fields for all systems.
          custom_definition = @cdefs[field]
          custom_definition ? obj.custom_value(custom_definition) : nil
        end

    end
  end
end
