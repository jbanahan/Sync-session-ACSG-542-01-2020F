module OpenChain
  module CustomHandler
    class PoloMslPlusEnterpriseHandler
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

      def send_and_delete_ack_file ack_file, original_file_name
        parts = original_file_name.split(".")
        ext = parts.slice!(-1)
        fn = "#{parts.join(".")}-ack.#{ext}"
        FtpSender.send_file("ftp.chain.io",'polo','pZZ117',ack_file,{:folder=>(Rails.env=='production' ? '/_to_msl' : '/_test_to_msl'),:remote_file_name=>fn})
        File.delete ack_file 
      end

      private 
      def cust_def label, data_type="string"
        CustomDefinition.find_or_create_by_label_and_module_type label, "Product", :data_type=>data_type
      end
    end
  end
end
