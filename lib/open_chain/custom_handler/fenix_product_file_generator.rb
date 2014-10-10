module OpenChain
  module CustomHandler
    class FenixProductFileGenerator
      include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport

      def initialize fenix_customer_code, options = {}
        @fenix_customer_code = fenix_customer_code
        @canada_id = Country.find_by_iso_code('CA').id
        @importer_id = options['importer_id']
        @use_part_number = (options['use_part_number'].to_s == "true")
        @additional_where = options['additional_where']
        @suppress_country = options['suppress_country']
        @suppress_description = (options['suppress_description'].to_s == "true")

        custom_defintions = []
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
          where("classifications.country_id = #{@canada_id} and length(tariff_records.hts_1) > 6").need_sync("fenix-#{@fenix_customer_code}")
        
        if @importer_id
          r = r.where(:importer_id => @importer_id)
        end

        if @additional_where
          r = r.where(@additional_where)
        end

        r
      end
      
      def make_file products
        t = Tempfile.new(["fenix-#{@fenix_customer_code}",'.txt'])
        products.each do |p|
          c = p.classifications.find_by_country_id(@canada_id)
          next unless c
          c.tariff_records.each do |tr|
            t << file_output(@fenix_customer_code, p, c, tr) unless tr.hts_1.blank?
          end

          sr = p.sync_records.where(trading_partner: "fenix-#{@fenix_customer_code}").first_or_initialize
          sr.sent_at = Time.now
          sr.confirmed_at = 1.second.from_now
          sr.confirmation_file_name = "Fenix Confirmation"
          sr.save!
        end
        t.flush
        t
      end

      def ftp_file f
        FtpSender.send_file('ftp2.vandegriftinc.com','VFITRack','RL2VFftp',f,{:folder=>'to_ecs/fenix_products',:remote_file_name=>File.basename(f.path)})
        f.unlink
      end

      def self.run_schedulable opts_hash={}
        OpenChain::CustomHandler::FenixProductFileGenerator.new(opts_hash["fenix_customer_code"], opts_hash).generate
      end
      
      private
        def file_output fenix_customer_code, p, c, tr
          line = "N#{"".ljust(14)}#{force_fixed(fenix_customer_code, 9)}#{"".ljust(7)}#{force_fixed identifier_field(p),40}#{tr.hts_1.ljust(10)}"
          
          if !@suppress_description
            # Description starts at zero-indexed position 135..add spacing to accomodate
            line += "".ljust(135 - line.length)
            line += force_fixed(c.get_custom_value(@cdefs[:class_customs_description]).value.to_s, 50)
          end

          if !@suppress_country
            # The country of origin field starts at zero-indexed position 359..add spacing to accomodate
            line += "".ljust(359 - line.length)
            line += force_fixed(p.get_custom_value(@cdefs[:prod_country_of_origin]).value.to_s, 3)
          end

          line += "\r\n"
        end

        def force_fixed str, len
          return str.ljust(len) if str.length <= len
          str[0,len]
        end

        def identifier_field p
          if @use_part_number
            p.get_custom_value(@cdefs[:prod_part_number]).value
          else
            p.unique_identifier
          end
        end

    end
  end
end
