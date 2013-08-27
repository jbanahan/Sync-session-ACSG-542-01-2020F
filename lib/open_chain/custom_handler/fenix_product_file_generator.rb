module OpenChain
  module CustomHandler
    class FenixProductFileGenerator
      def initialize(fenix_customer_code, importer_id = nil, use_part_number = false, additional_where = nil) 
        @fenix_customer_code = fenix_customer_code
        @canada_id = Country.find_by_iso_code('CA').id
        @importer_id = importer_id
        @use_part_number = use_part_number
        @additional_where = additional_where
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
            t << "N#{"".ljust(14)}#{force_fixed @fenix_customer_code, 9}#{"".ljust(7)}#{force_fixed identifier_field(p),40}#{tr.hts_1.ljust(10)}\r\n" unless tr.hts_1.blank?
          end
          sr = p.sync_records.find_by_trading_partner("fenix-#{@fenix_customer_code}")
          sr = p.sync_records.build(:trading_partner=>"fenix-#{@fenix_customer_code}") unless sr
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

      private
      def force_fixed str, len
        return str.ljust(len) if str.length <= len
        str[0,len]
      end

      def identifier_field p
        if @use_part_number
          @part_number_def ||= CustomDefinition.find_by_label_and_module_type("Part Number","Product")

          p.get_custom_value(@part_number_def).value
        else
          p.unique_identifier
        end
      end
    end
  end
end
