require 'bigdecimal'
require 'open_chain/alliance_imaging_client'
module OpenChain
  class AllianceParser
    SOURCE_CODE = 'Alliance'
    DATE_MAP = {'00012'=>:arrival_date,
      '00016'=>:entry_filed_date,
      '00019'=>:release_date,
      '99202'=>:first_release_date,
      '00052'=>:free_date,
      '00028'=>:last_billed_date,
      '00032'=>:invoice_paid_date,
      '00044'=>:liquidation_date,
      '00042'=>:duty_due_date,
      '00001'=>:export_date,
      '00004'=>:file_logged_date,
      '00020'=>:fda_release_date,
      '93002'=>:fda_review_date,
      '00108'=>:fda_transmit_date,
      '92007'=>:isf_sent_date,
      '92008'=>:isf_accepted_date,
      '00003'=>:docs_received_date,
      '00098'=>:docs_received_date, #both 00003 and 00098 are docs received for different customers
      '00024'=>:trucker_called_date,
      '00052'=>:free_date,
      '00085'=>:edi_received_date,
      '99212'=>:first_entry_sent_date,
      '99310'=>:monthly_statement_received_date,
      '99311'=>:monthly_statement_paid_date,
      '00048'=>:daily_statement_due_date,
      '00121'=>:daily_statement_approved_date
    }

    def self.process_past_days number_of_days, opts={:imaging=>false}
      number_of_days.times {|i| process_day i.days.ago, opts}
      if opts[:user_id]
        u = User.find opts[:user_id]
        u.messages.create(:subject=>"Alliance reprocessing complete.",:body=>"#{number_of_days} days have been reprocessed for Alliance")
      end
    end
    # process all files in the archive for a given date.  Use this to reprocess old files. By default it skips the call to the imaging server
    def self.process_day date, opts={:imaging=>false}
      OpenChain::S3.integration_keys(date,"/opt/wftpserver/ftproot/www-vfitrack-net/_alliance") do |key|
        process_from_s3 OpenChain::S3.integration_bucket_name, key
      end
    end

    def self.process_from_s3 bucket, key, opts={}
      parse OpenChain::S3.get_data(bucket, key), {:bucket=>bucket, :key=>key}.merge(opts)
    end

    # take the text inside an internet tracking file from alliance and create/update the entry
    def self.parse file_content, opts={}
      current_line = 0
      entry_lines = []
      file_content.lines.each_with_index do |line,idx|
        current_line = idx
        prefix = line[0,4]
        if !entry_lines.empty? && prefix=="SH00"
          AllianceParser.new(file_content,current_line).parse_entry entry_lines, opts
          entry_lines = []
        end
        entry_lines << line
      end
      AllianceParser.new(file_content,current_line).parse_entry entry_lines, opts if !entry_lines.empty?
    end

    def initialize(file_content,starting_row=0)
      @file_content = file_content
      @starting_row = starting_row
    end

    def parse_entry rows, opts={}
      inner_opts = {:imaging=>true}.merge(opts)
      bucket_name = inner_opts[:bucket]
      s3_key = inner_opts[:key]
      current_row = @starting_row
      row_content = nil
      begin
        Entry.transaction do 
          start_time = Time.now
          rows.each do |r|
            row_content = r
            current_row += 1
            break if @skip_entry
            prefix = r[0,4]
            case prefix
              when "SH00"
                process_sh00 r
              when "SH01"
                process_sh01 r
              when "SH03"
                process_sh03 r
              when "SH04"
                process_sh04 r
              when "SD00"
                process_sd00 r
              when "IH00"
                process_ih00 r
              when "IT00"
                process_it00 r
              when "IL00"
                process_il00 r
              when "SI00"
                process_si00 r
              when "SR00"
                process_sr00 r
              when "SU01"
                process_su01 r
              when "CI00"
                process_ci00 r
              when "CL00"
                process_cl00 r
              when "CT00"
                process_ct00 r
              when "CF00"
                process_cf00 r
              when "SC00"
                process_sc00 r
              when "SN00" 
                process_sn00 r
            end
            current_row += 1
          end
          if !@skip_entry
            @entry.last_file_bucket = bucket_name
            @entry.last_file_path = s3_key
            @entry.import_country = Country.find_by_iso_code('US')
            @entry.it_numbers = accumulated_string :it_number 
            @entry.master_bills_of_lading = accumulated_string :mbol 
            @entry.house_bills_of_lading = accumulated_string :hbol 
            @entry.sub_house_bills_of_lading = accumulated_string :sub 
            [:cust_ref,:po_numbers].each {|x| @accumulated_strings[x] ||= []}
            @entry.customer_references = (@accumulated_strings[:cust_ref].to_a - @accumulated_strings[:po_numbers].to_a).join("\n ")
            @entry.mfids = accumulated_string :mfid
            @entry.export_country_codes = accumulated_string :export_country_codes
            @entry.origin_country_codes = accumulated_string :origin_country_codes
            @entry.vendor_names = accumulated_string :vendor_names
            @entry.total_units_uoms = accumulated_string :total_units_uoms
            @entry.special_program_indicators = accumulated_string :spis
            @entry.po_numbers = accumulated_string :po_numbers
            @entry.container_numbers = accumulated_string :container_numbers
            @entry.container_sizes = accumulated_string :container_sizes
            @entry.charge_codes = accumulated_string :charge_codes
            @entry.broker_invoice_total = @entry.broker_invoices.inject(0) { |sum, bi| sum += (bi.invoice_total || 0) }
            set_fcl_lcl_value if @accumulated_strings[:fcl_lcl]
            set_importer_id
            @entry.save! if @entry
            #set time to process in milliseconds without calling callbacks
            @entry.connection.execute "UPDATE entries SET time_to_process = #{((Time.now-start_time) * 1000).to_i.to_s} WHERE ID = #{@entry.id}"
            OpenChain::AllianceImagingClient.request_images @entry.broker_reference if opts[:imaging]
          end
          @skip_entry = false
        end
      rescue
        puts $!
        puts $!.backtrace
        tmp = Tempfile.new(['alliance_error','.txt'])
        tmp << @file_content
        tmp.flush
        $!.log_me ["Alliance parser failure, line #{current_row}.","Row: #{row_content}"], [tmp.path]
      end
    end

    private 
    # header
    def process_sh00 r
      brok_ref = r[4,10].gsub(/^[0]*/,'')
      @accumulated_strings = Hash.new
      @entry = Entry.find_by_broker_reference_and_source_system brok_ref, SOURCE_CODE
      if @entry && @entry.last_exported_from_source && @entry.last_exported_from_source > parse_date_time(r[24,12]) #if current is newer than file
        @skip_entry = true
      else
        @entry = Entry.new(:broker_reference=>brok_ref) unless @entry
        @entry.source_system = SOURCE_CODE
        @entry.commercial_invoices.destroy_all #clear all invoices and recreate as we go
        @entry.broker_invoices.destroy_all #clear all invoices and recreate as we go
        @entry.entry_comments.destroy_all
        @entry.total_invoiced_value = 0 #reset, then accumulate as we process invoices
        @entry.total_units = 0 #reset, then accumulate as we process invoice lines
        @entry.customer_number = r[14,10].strip
        @entry.last_exported_from_source = parse_date_time r[24,12]
        @entry.company_number = r[36,2].strip
        @entry.division_number = r[38,4].strip
        @entry.customer_name = r[42,35].strip
        @entry.entry_type = r[166,2].strip
        @entry.entry_number = "#{r[168,3]}#{r[172,8]}"
        @entry.carrier_code = r[225,4].strip
        @entry.total_packages = r[300,12]
        @entry.total_packages_uom = r[312,6].strip
        @entry.merchandise_description = r[77,70].strip
        @entry.transport_mode_code = r[164,2]
        @entry.entry_port_code = port_code r[160,4]
        @entry.lading_port_code = port_code r[151,5]
        @entry.unlading_port_code = port_code r[156,4]
        @entry.ult_consignee_code = r[180,10].strip
        @entry.ult_consignee_name = r[190,35].strip
        @entry.vessel = r[270,20].strip
        @entry.voyage = r[290,10].strip
        @entry.gross_weight = r[318,12]
        @entry.daily_statement_number = r[347,11].strip
        @entry.pay_type = r[358] 
        @entry.liquidation_type_code = r[364,2]
        @entry.liquidation_type = r[366,35].strip
        @entry.liquidation_action_code = r[401,2]
        @entry.liquidation_action_description = r[403,35].strip
        @entry.liquidation_extension_code = r[438,2]
        @entry.liquidation_extension_description = r[440,35].strip
        @entry.liquidation_extension_count = r[475]
        @entry.census_warning = parse_boolean r[497]
        @entry.error_free_release = parse_boolean r[498]
        @entry.paperless_certification = parse_boolean r[499]
        @entry.paperless_release = parse_boolean r[500]
      end
    end

    # header continuation
    def process_sh01 r
      @entry.release_cert_message = r[4,33].strip
      @entry.total_duty = parse_currency r[49,12]
      @entry.liquidation_duty = parse_currency r[61,12]
      @entry.total_fees = parse_currency r[85,12]
      @entry.liquidation_fees = parse_currency r[97,12]
      @entry.liquidation_tax = parse_currency r[133,12]
      @entry.liquidation_ada = parse_currency r[169,12]
      @entry.liquidation_cvd = parse_currency r[205,12]
      @entry.liquidation_total = @entry.liquidation_duty + @entry.liquidation_fees + @entry.liquidation_tax + @entry.liquidation_ada + @entry.liquidation_cvd
      @entry.fda_message = r[217,33].strip
      @entry.total_duty_direct = parse_currency r[357,12]
      @entry.entered_value = parse_currency r[384,13]
      accumulate_string :recon, "NAFTA" if r[397]!="N"
      accumulate_string :recon, "VALUE" if r[398]!="N"
      accumulate_string :recon, "CLASS" if r[399]!="N"
      accumulate_string :recon, "9802" if r[400]!="N"
      @entry.monthly_statement_number = r[413,11].strip
      @entry.monthly_statement_due_date = parse_date r[439,8]
      @entry.recon_flags = accumulated_string(:recon)
    end

    # header continuation 3
    def process_sh03 r
      @entry.consignee_address_1 = r[288,35].strip
      @entry.consignee_address_2 = r[323,35].strip
      @entry.consignee_city = r[358,35].strip
      @entry.consignee_state = r[393,2].strip
    end

    def process_sh04 r
      @entry.destination_state = r[191,2].strip
    end

    # date
    def process_sd00 r
      d = r[9,12]
      dp = DATE_MAP[r[4,5]]
      @entry.attributes= {dp=>parse_date_time(d)} if dp
    end

    # fees
    def process_su01 r
      v = parse_currency r[42,11]
      case r[39,3]
      when '056'
        @entry.cotton_fee = v
      when '499'
        @entry.mpf = v
      when '501'
        @entry.hmf = v
      end
    end

    # commercial invoice header
    def process_ci00 r

      @commercial_invoices ||= []
      @c_invoice = nil #reset since we're building a new one 
      @c_invoice = @entry.commercial_invoices.build
      @commercial_invoices << @c_invoice
      @c_invoice.invoice_number = r[4,22].strip
      @c_invoice.currency = r[26,3].strip
      @c_invoice.exchange_rate = parse_decimal r[29,8], 6
      @c_invoice.invoice_value_foreign = parse_currency r[37,13]
      @c_invoice.country_origin_code = r[63,2].strip
      @c_invoice.gross_weight = r[65,12]
      @c_invoice.total_charges = parse_currency r[77,11]
      @c_invoice.invoice_date = parse_date r[88,8]

      mfid = r[96,15].strip
      @c_invoice.mfid = mfid
      accumulate_string :mfid, mfid

      invoice_value = parse_currency r[50,13]
      @c_invoice.invoice_value = invoice_value
      @entry.total_invoiced_value += parse_currency r[50,13]
    end

    # commercial invoice line
    def process_cl00 r
      @c_line = @c_invoice.commercial_invoice_lines.build
      @c_line.mid = r[52,15].strip
      @c_line.part_number = r[4,30].strip
      @c_line.po_number = r[180,35].strip
      @c_line.quantity = parse_decimal r[34,12], 3
      @c_line.unit_of_measure = r[46,6].strip
      @c_line.value = parse_currency r[273,13] 
      @c_line.country_origin_code = r[67,2].strip
      @c_line.country_export_code = r[80,2]
      @c_line.related_parties = r[82]=='Y'
      @c_line.vendor_name = r[83,35].strip
      @c_line.volume = parse_currency r[118,11] #not really currency, but 2 decimals, so it's ok
      @c_line.unit_price = @c_line.value / @c_line.quantity if @c_line.value > 0 && @c_line.quantity > 0
      @c_line.department = r[147,6].strip
      @c_line.computed_value = parse_currency r[260,13]
      @c_line.computed_adjustments = parse_currency r[299,13]
      @c_line.computed_net_value = parse_currency r[312,13]
      accumulate_string :export_country_codes, @c_line.country_export_code
      accumulate_string :origin_country_codes, @c_line.country_origin_code
      accumulate_string :vendor_names, @c_line.vendor_name 
      accumulate_string :total_units_uoms, @c_line.unit_of_measure 
      accumulate_string :po_numbers, r[180,35].strip
      @entry.total_units += @c_line.quantity 
    end

    # commercial invoice line - fees
    def process_cf00 r
      val = parse_currency r[7,11]
      case r[4,3]
        when '499'
          @c_line.mpf = val
        when '501'
          @c_line.hmf = val
      end
    end
    # commercial invoice line - tariff
    def process_ct00 r
      @ct = @c_line.commercial_invoice_tariffs.build
      @ct.hts_code = r[32,10].strip.ljust(10,"0")
      @ct.duty_amount = parse_currency r[4,12]
      @ct.entered_value = parse_currency r[16,13]
      @ct.duty_rate = @ct.entered_value > 0 ? @ct.duty_amount / @ct.entered_value : 0
      @ct.spi_primary = r[29,2].strip
      @ct.spi_secondary = r[31].strip
      @ct.classification_qty_1 = parse_currency r[42,12]
      @ct.classification_qty_2 = parse_currency r[60,12]
      @ct.classification_qty_3 = parse_currency r[78,12]
      @ct.classification_uom_1 = r[54,6].strip
      @ct.classification_uom_2 = r[72,6].strip
      @ct.classification_uom_3 = r[90,6].strip
      @ct.tariff_description = r[96,35].strip
      gw = r[131,12].to_i
      @ct.gross_weight = gw unless gw.nil?
      accumulate_string :spis, @ct.spi_primary 
      accumulate_string :spis, @ct.spi_secondary
    end

    # invoice header
    def process_ih00 r
      @invoice = @entry.broker_invoices.build(:suffix=>r[4,2],:currency=>"USD")
      @invoice.invoice_date = parse_date r[6,8] unless r[6,8] == "00000000"
      @invoice.invoice_total = parse_currency r[24,11]
      @invoice.customer_number = r[14,10].strip
      @invoice.bill_to_name = r[83,35].strip
      @invoice.bill_to_address_1 = r[118,35].strip
      @invoice.bill_to_address_2 = r[153,35].strip
      @invoice.bill_to_city = r[188,35].strip
      @invoice.bill_to_state = r[223,2].strip
      @invoice.bill_to_zip = r[225,9].strip
      @invoice.bill_to_country = Country.find_by_iso_code(r[234,2]) unless r[234,2].strip.blank?
    end

    # invoice line
    def process_il00 r
      line = @invoice.broker_invoice_lines.build
      line.charge_code = r[4,4].strip
      accumulate_string :charge_codes, line.charge_code
      line.charge_description = r[8,35].strip
      line.charge_amount = parse_currency r[43,11]
      line.vendor_name = r[54,30].strip
      line.vendor_reference = r[84,15].strip
      line.charge_type = r[99,1]
    end

    # invoice trailer
    def process_it00 r
      @invoice = nil
    end

    # tracking numbers
    def process_si00 r
      accumulate_string :it_number, r[4,12].strip
      accumulate_string :mbol, r[16,16].strip
      accumulate_string :hbol, r[32,12].strip
      accumulate_string :sub, r[44,12].strip
    end

    # customer references
    def process_sr00 r
      accumulate_string :cust_ref, r[4,35].strip 
    end

    # containers
    def process_sc00 r
      accumulate_string :container_numbers, r[4,15].strip
      cont_size_num = r[59,7].strip
      cont_size_desc = r.size>283 ? r[283,40].strip : ""
      accumulate_string :container_sizes, (cont_size_desc.blank? ? cont_size_num : "#{cont_size_num}-#{cont_size_desc}")
      accumulate_string :fcl_lcl, r[271] unless r[271].blank?
    end
    
    #comments
    def process_sn00 r
      @entry.entry_comments.build(:body=>r[4,60].strip,:username=>r[79,12].strip,:generated_at=>parse_date_time(r[64,12]))
    end

    # make port code nil if all zeros
    def port_code v
      v.blank? || v.match(/^[0]*$/) ? nil : v
    end

    # match importer_id
    def set_importer_id 
      raise "Alliance @entry received without customer number" unless @entry.customer_number
      @entry.importer = Company.find_or_create_by_alliance_customer_number(:alliance_customer_number=>@entry.customer_number, :name=>@entry.customer_name, :importer=>true)
    end

    # set the fcl_lcl value based on the accumulated flags from the container lines
    def set_fcl_lcl_value
      vals = @accumulated_strings[:fcl_lcl]
      v = nil
      if !vals.blank?
        if vals.size == 1
          case vals.first
            when 'F'
              v = "FCL"
            when 'L'
              v = "LCL"
          end
        elsif vals.size > 1
          v = 'Mixed'
        end
      end
      @entry.fcl_lcl = v
    end

    def parse_date str
      return nil if str.blank? || str.match(/^[0]*$/)
      Date.parse str
    end
    def parse_date_time str
      return nil if str.blank? || str.match(/^[0]*$/)
      ActiveSupport::TimeZone["Eastern Time (US & Canada)"].parse str
    end
    def parse_decimal str, decimal_places
      offset = -(decimal_places+1)
      BigDecimal.new str.insert(offset,"."), decimal_places
    end
    def parse_currency str
      parse_decimal str, 2
    end

    def accumulate_string string_code, value
      @accumulated_strings ||= Hash.new
      @accumulated_strings[string_code] ||= Set.new
      @accumulated_strings[string_code] << value unless value.blank?
    end
    def accumulated_string string_code
      return "" unless @accumulated_strings && @accumulated_strings[string_code]
      @accumulated_strings[string_code].to_a.join("\n ")
    end
    def parse_boolean str
      str=='Y'
    end
  end
end
