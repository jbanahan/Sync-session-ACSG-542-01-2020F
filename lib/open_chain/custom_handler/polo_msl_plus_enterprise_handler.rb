require 'open_chain/custom_handler/ack_file_handler'
require 'open_chain/custom_handler/polo/polo_custom_definition_support'

module OpenChain
  module CustomHandler
    class PoloMslPlusEnterpriseHandler
      include OpenChain::CustomHandler::Polo::PoloCustomDefinitionSupport

      # :env=>:qa will put files in _test_to_msl instead of _to_msl
      def initialize opts={}
        o = HashWithIndifferentAccess.new(opts)
        @env = o[:env].to_sym if o[:env]
      end

      def self.run_schedulable opts
        g = self.new(opts)
        prods = g.products_to_send.where("sync_records.sent_at < ? or sync_records.sent_at is null",6.hours.ago).limit(1000)
        while prods.count > 0
          g.send_and_delete_sync_file g.generate_outbound_sync_file prods
          prods = g.products_to_send.where("sync_records.sent_at < ? OR sync_records.sent_at is null",6.hours.ago).limit(1000)
        end
      end

      # find the products that need to be sent to MSL+ (they have MSL+ Receive Dates and need sync)
      def products_to_send
        init_outbound_custom_definitions
        cd_msl_rec = @out_cdefs[:msl_receive_date]
        cd_csm_num = @out_cdefs[:csm_numbers]
        Product.select("distinct products.*").need_sync("MSLE").
          joins("LEFT OUTER JOIN custom_values rd ON products.id = rd.customizable_id AND rd.customizable_type = 'Product' AND rd.custom_definition_id = #{cd_msl_rec.id}").
          joins("LEFT OUTER JOIN custom_values csm ON products.id = csm.customizable_id AND csm.customizable_type = 'Product' AND csm.custom_definition_id = #{cd_csm_num.id}").
          where("TRIM(csm.text_value) != '' OR rd.date_value IS NOT NULL")
      end

      # Generate the file with data that needs to be sent back to MSL+
      def generate_outbound_sync_file products
        file = Tempfile.new(['msl_outbound','.csv'])
        headers = ["Style", "Country", "MP1 Flag", "HTS 1", "HTS 2", "HTS 3", "Length", "Width", "Height"]
        (1..15).each do |x|
          headers << "Fabric Type - #{x}"
          headers << "Fabric - #{x}"
          headers << "Fabric % - #{x}"
        end
        headers.push *["Knit / Woven?", "Fiber Content %s", "Common Name 1", "Common Name 2", "Common Name 3", 
          "Scientific Name 1", "Scientific Name 2", "Scientific Name 3", "F&W Origin 1", "F&W Origin 2", "F&W Origin 3",
          "F&W Source 1", "F&W Source 2", "F&W Source 3", "Origin of Wildlife", "Semi-Precious", "Type of Semi-Precious", "CITES", "Fish & Wildlife"]

        file << headers.to_csv
        dont_send_countries = Country.where("iso_code IN (?)",['US','CA']).collect{|c| c.id}
        init_outbound_custom_definitions
        products.each do |p|
          classifications = p.classifications.includes(:country, :tariff_records).where("not classifications.country_id IN (?)",dont_send_countries)
          classifications.each do |cl|
            iso = cl.country.iso_code
            cl.tariff_records.order("line_number ASC").each do |tr|
              file << outbound_file_content(p, cl, tr, iso).to_csv
            end
          end
          sr = p.sync_records.find_or_initialize_by_trading_partner("MSLE")
          sr.update_attributes(:sent_at=>Time.now)
        end
        file.flush
        file
      end

      # Send the file created by `generate_outbound_sync_file`
      def send_and_delete_sync_file local_file, send_time=Time.now #only override send_time for test case
        send_file local_file, "ChainIO_HTSExport_#{send_time.strftime('%Y%m%d%H%M%S')}.csv"
        File.delete local_file 
      end

      #process the inbound file
      def process file_content
        init_inbound_custom_definitions
        field_map = {
          @in_defs[:msl_us_season] => 1,
          @in_defs[:msl_board_number] => 2,
          @in_defs[:msl_item_desc] => 3,
          @in_defs[:msl_model_desc] => 4,
          @in_defs[:msl_gcc_desc] => 5,
          @in_defs[:msl_hts_desc] => 6,
          @in_defs[:msl_hts_desc_2] => 7,
          @in_defs[:msl_hts_desc_3] => 8,
          @in_defs[:ax_subclass] => 9,
          @in_defs[:msl_us_brand] => 10,
          @in_defs[:msl_us_sub_brand] => 11,
          @in_defs[:msl_us_class] => 12
        }
        current_style = nil
        ack_file = Tempfile.new(['msl_ack','.csv'])
        ack_file << ['Style','Time Processed','Status'].to_csv
        begin 
          CSV.parse(file_content,:headers=>true) do |row|
            begin
            current_style = row[0]
            p = Product.find_or_create_by_unique_identifier current_style
            field_map.each {|k,v| p.update_custom_value! k,row[v]} 
            p.update_custom_value! @in_defs[:msl_receive_date], Date.today
            ack_file << [current_style,DateTime.now.utc.strftime("%Y%m%d%H%M%S"),"OK"].to_csv
            rescue
              ack_file << [current_style,DateTime.now.utc.strftime("%Y%m%d%H%M%S"),$!.message].to_csv
            end
          end
        rescue
          t = nil
          begin
            t = Tempfile.new(['msl_bad_file','.csv'])
            t << file_content
            t.flush
          rescue
            $!.log_me
          end
          $!.log_me ["MSL+ File Processing Error"], (t ? [t] : [])
          #write error here and log it
          ack_file << "INVALID CSV FILE ERROR: #{$!.message}"
        ensure
          ack_file.flush
        end
        ack_file
      end

      #transmit the inbound file generated by process(file_content)
      def send_and_delete_ack_file ack_file, original_file_name
        parts = original_file_name.split(".")
        ext = parts.slice!(-1)
        fn = "#{parts.join(".")}-ack.#{ext}"
        send_file ack_file, fn
        File.delete ack_file 
      end

      def send_file local_file, destination_file_name
        FtpSender.send_file("connect.vfitrack.net",'polo','pZZ117',local_file,{:folder=>(@env==:qa ? '/_test_to_msl' : '/_to_msl'),:remote_file_name=>destination_file_name})
      end

      private 
        def cust_def label, data_type="string"
          CustomDefinition.find_or_create_by_label_and_module_type label, "Product", :data_type=>data_type
        end
        def hts_value hts, country_iso
          h = hts.nil? ? "" : hts
          country_iso=="TW" ? h : h.hts_format
        end
        def mp1_value tariff_record, country_iso
          return "" unless country_iso == 'TW'
          found = OfficialTariff.
            where("hts_code IN (?)",[tariff_record.hts_1,tariff_record.hts_2,tariff_record.hts_3].compact).
            where("country_id = (SELECT ID from countries where iso_code = \"TW\")").
            where("import_regulations like \"%MP1%\"").count
          found > 0 ? "true" : ""
        end

        def init_outbound_custom_definitions
          if @out_cdefs.nil?
            cdefs = [:length_cm, :width_cm, :height_cm, :msl_receive_date, :csm_numbers]
            (1..15).each do |x|
              cdefs << "fabric_type_#{x}".to_sym
              cdefs << "fabric_#{x}".to_sym
              cdefs << "fabric_percent_#{x}".to_sym
            end

            cdefs.push :knit_woven, :fiber_content, :common_name_1, :common_name_2, :common_name_3, :scientific_name_1, :scientific_name_2, :scientific_name_3,
                        :fish_wildlife_origin_1, :fish_wildlife_origin_2, :fish_wildlife_origin_3, :fish_wildlife_source_1, :fish_wildlife_source_2, :fish_wildlife_source_3,
                        :origin_wildlife, :semi_precious, :semi_precious_type, :cites, :fish_wildlife

            @out_cdefs = self.class.prep_custom_definitions cdefs
          end
          @out_cdefs
        end

        def init_inbound_custom_definitions
          if @in_defs.nil?
            @in_defs = self.class.prep_custom_definitions [:msl_receive_date, :msl_us_class, :msl_us_brand, :msl_us_sub_brand, :msl_model_desc, 
                          :msl_hts_desc, :msl_hts_desc_2, :msl_hts_desc_3, :ax_subclass, :msl_item_desc, :msl_us_season, 
                          :msl_gcc_desc, :msl_board_number]
          end
          @in_defs
        end

        def outbound_file_content p, cl, tr, iso
          file = [p.unique_identifier, iso, mp1_value(tr,iso), hts_value(tr.hts_1,iso), hts_value(tr.hts_2,iso), hts_value(tr.hts_3,iso)]
          file.push *get_custom_values(p, :length_cm, :width_cm, :height_cm)

          # This is just filler for the fiber 1-15 fields we're not sending yet
          45.times {file << nil}

          file.push *get_custom_values(p, :knit_woven, :fiber_content, :common_name_1, :common_name_2, :common_name_3, :scientific_name_1, :scientific_name_2, :scientific_name_3,
                        :fish_wildlife_origin_1, :fish_wildlife_origin_2, :fish_wildlife_origin_3, :fish_wildlife_source_1, :fish_wildlife_source_2, :fish_wildlife_source_3,
                        :origin_wildlife, :semi_precious, :semi_precious_type, :cites, :fish_wildlife)

          # Change all newlines to spaces
          file.map {|v| v.is_a?(String) ? v.gsub(/\r?\n/, " ") : v}
        end

        def get_custom_values product, *defs
          defs.map {|d| product.get_custom_value(@out_cdefs[d]).value }
        end
    end
  end
end