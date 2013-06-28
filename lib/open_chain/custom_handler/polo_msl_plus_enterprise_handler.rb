require 'open_chain/custom_handler/ack_file_handler'
module OpenChain
  module CustomHandler
    class PoloMslPlusEnterpriseHandler
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
        cd_msl_rec = cust_def "MSL+ Receive Date", "date"
        sc = SearchCriterion.new(:model_field_uid=>"*cf_#{cd_msl_rec.id}",:operator=>"notnull")
        sc.apply(Product.select("distinct products.*").need_sync("MSLE"))
      end

      # Generate the file with data that needs to be sent back to MSL+
      def generate_outbound_sync_file products
        file = Tempfile.new(['msl_outbound','.csv'])
        file << ["Style", "Country", "MP1 Flag", "HTS 1", "HTS 2", "HTS 3", "Length", "Width", "Height"].to_csv
        dont_send_countries = Country.where("iso_code IN (?)",['US','CA','IT']).collect{|c| c.id}
        cd_length, cd_width, cd_height = ["Length (cm)","Width (cm)","Height (cm)"].collect {|lbl| CustomDefinition.find_by_label lbl}
        products.each do |p|
          classifications = p.classifications.includes(:country).where("not classifications.country_id IN (?)",dont_send_countries)
          classifications.each do |cl|
            iso = cl.country.iso_code
            cl.tariff_records.each do |tr|
              file << [p.unique_identifier,cl.country.iso_code,mp1_value(tr,iso),hts_value(tr.hts_1,iso),hts_value(tr.hts_2,iso),hts_value(tr.hts_3,iso),
                p.get_custom_value(cd_length).value,p.get_custom_value(cd_width).value,p.get_custom_value(cd_height).value].to_csv
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
        cd_board = cust_def "Board Number"
        cd_gcc_desc = cust_def "GCC Description"
        cd_msl_hts = cust_def "MSL+ HTS Description"
        cd_msl_season = cust_def "MSL+ US Season"
        cd_msl_itm = cust_def "MSL+ Item Description"
        cd_msl_model = cust_def "MSL+ Model Description"
        cd_msl_hts_2 = cust_def "MSL+ HTS Description 2"
        cd_msl_hts_3 = cust_def "MSL+ HTS Description 3"
        cd_ax_sub = cust_def "AX Subclass"
        cd_msl_us_brand = cust_def "MSL+ US Brand"
        cd_msl_us_sub = cust_def "MSL+ US Sub Brand"
        cd_msl_us_cls = cust_def "MSL+ US Class"
        cd_msl_rec = cust_def "MSL+ Receive Date", "date"
        field_map = {
          cd_board=>2,
          cd_gcc_desc=>5,
          cd_msl_hts => 6,
          cd_msl_season => 1,
          cd_msl_itm => 3,
          cd_msl_model => 4,
          cd_msl_hts_2 => 7,
          cd_msl_hts_3 => 8,
          cd_ax_sub => 9,
          cd_msl_us_brand => 10,
          cd_msl_us_sub => 11,
          cd_msl_us_cls => 12
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
            p.update_custom_value! cd_msl_rec, Date.today
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
        FtpSender.send_file("ftp.chain.io",'polo','pZZ117',local_file,{:folder=>(@env==:qa ? '/_test_to_msl' : '/_to_msl'),:remote_file_name=>destination_file_name})
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
    end
  end
end
