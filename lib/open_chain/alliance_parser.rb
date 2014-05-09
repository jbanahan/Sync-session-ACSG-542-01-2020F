require 'bigdecimal'
require 'open_chain/alliance_imaging_client'
require 'open_chain/integration_client_parser'
require 'open_chain/sql_proxy_client'

module OpenChain
  class AllianceParser
    extend OpenChain::IntegrationClientParser
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
      '00121'=>:daily_statement_approved_date,
      '00011'=>:eta_date,
      '00025'=>:delivery_order_pickup_date,
      '00026'=>:freight_pickup_date
    }

    def self.integration_folder
      "/opt/wftpserver/ftproot/www-vfitrack-net/_alliance"
    end
    # take the text inside an internet tracking file from alliance and create/update the entry
    def self.parse file_content, opts={}
      current_line = 0
      entry_lines = []
      file_content.each_line.each_with_index do |line,idx|
        current_line = idx
        prefix = line[0,4]
        if !entry_lines.empty? && prefix=="SH00"
          AllianceParser.new.parse_entry entry_lines, opts
          entry_lines = []
        end
        entry_lines << line
      end
      AllianceParser.new.parse_entry entry_lines, opts if !entry_lines.empty?
    end

    def parse_entry rows, opts={}
      @entry = nil
      inner_opts = {:imaging=>true}.merge(opts)
      bucket_name = inner_opts[:bucket]
      s3_key = inner_opts[:key]
      current_row = 1
      row_content = rows[0]
      processed = false
      begin
        entry_information = extract_entry_information(rows)
        return false if entry_information[:broker_reference].blank?

        find_and_process_entry(entry_information) do |entry|
          # This block is run inside a transaction...no need to start another one
          @entry = entry
          @entry.containers.destroy_all
          @accumulated_strings = Hash.new

          start_time = Time.now
          rows.each do |r|
            row_content = r
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
              when "CI01"
                process_ci01 r
              when "CL00"
                process_cl00 r
              when "CL01"
                process_cl01 r
              when "CT00"
                process_ct00 r
              when "CF00"
                process_cf00 r
              when "SC00"
                process_sc00 r
              when "SN00" 
                process_sn00 r
              when "CP00"
                process_cp00 r
            end
            current_row += 1
          end
         
          @entry.last_file_bucket = bucket_name
          @entry.last_file_path = s3_key
          @entry.import_country = Country.find_by_iso_code('US')
          @entry.it_numbers = accumulated_string :it_number 
          @entry.master_bills_of_lading = accumulated_string :mbol 
          @entry.house_bills_of_lading = accumulated_string :hbol 
          @entry.sub_house_bills_of_lading = accumulated_string :sub 
          [:cust_ref,:po_numbers,:part_numbers].each {|x| @accumulated_strings[x] ||= []}
          @entry.customer_references = (@accumulated_strings[:cust_ref].to_a - @accumulated_strings[:po_numbers].to_a).join("\n ")
          @entry.mfids = accumulated_string :mfid
          @entry.export_country_codes = accumulated_string :export_country_codes
          @entry.origin_country_codes = accumulated_string :origin_country_codes
          @entry.vendor_names = accumulated_string :vendor_names
          @entry.total_units_uoms = accumulated_string :total_units_uoms
          @entry.special_program_indicators = accumulated_string :spis
          @entry.po_numbers = accumulated_string :po_numbers
          @entry.part_numbers = accumulated_string :part_numbers
          @entry.container_numbers = accumulated_string :container_numbers
          @entry.container_sizes = accumulated_string :container_sizes
          @entry.charge_codes = accumulated_string :charge_codes
          @entry.commercial_invoice_numbers = accumulated_string :commercial_invoice_number
          @entry.broker_invoice_total = @entry.broker_invoices.inject(0) { |sum, bi| sum += (bi.invoice_total || 0) }
          set_fcl_lcl_value if @accumulated_strings[:fcl_lcl]
          set_importer_id

          @entry.save!
          #set time to process in milliseconds without calling callbacks
          @entry.update_column :time_to_process, ((Time.now-start_time) * 1000)

          processed = true
        end

        if @entry
          OpenChain::AllianceImagingClient.request_images @entry.broker_reference if inner_opts[:imaging]
          OpenChain::SqlProxyClient.delay.request_alliance_entry_details(@entry.broker_reference, @entry.last_exported_from_source)

          # This needs to go outside the lock/transaction so the listeners on the event all don't have to run inside the transaction
          @entry.broadcast_event(:save) if @entry
        end

      rescue => e
        raise e unless Rails.env.production?

        tmp = Tempfile.new(['alliance_error','.txt'])
        # Only store off the actual lines we're processing from the source file
        tmp << rows.join("\n")
        tmp.flush
        e.log_me ["Alliance parser failure, line #{current_row}.","Row: #{row_content}"], [tmp.path]
      end

      processed
    end

    def self.process_alliance_query_details results, context
      results = (results.is_a?(String) ? JSON.parse(results) : results)
      context = (context.is_a?(String) ? JSON.parse(context) : context)

      # The query results get posted back here regardless of if the file number was found or not, so just bail if the results don't have any values in them
      return if results.size == 0

      self.new.process_alliance_query_details results, context
    end

    def process_alliance_query_details results, context
      # Context should contain the file number and the last exported from source of the entry as it stood when the request was initially
      # made.  We can then use the same find_and_process_entry process as is used for preventing processing out of date alliance files
      # to prevent us from also processing out of date responses.
      last_exported_from_source = context['last_exported_from_source'].blank? ? nil : timezone.parse(context['last_exported_from_source'])
      entry_information = {broker_reference: context['broker_reference'], last_exported_from_source: last_exported_from_source}

      outer_entry = nil
      find_and_process_entry(entry_information) do |entry|
        # Each line from the results is going to be a hash from a DB query sent back by the Alliance SQL Proxy, the data goes down to the tariff level and is 
        # sorted together by invoice number, invoice line, tariff line
        # Use the first line for entry header information.
        header = results.first
        entry.final_statement_date = parse_date "#{nil_blank(header["final statement date"], true)}"

        invoices = extract_invoice_information_from_query_lines results
        invoices.values.each do |invoice_data|
          invoice = entry.commercial_invoices.find {|i| i.invoice_number == invoice_data[:header]["invoice number"]}
          next unless invoice

          invoice_data[:lines].values.each do |line_data|
            line = line_data[:line]
            inv_line_number = line["line number"].to_i/10
            invoice_line = invoice.commercial_invoice_lines.find {|l| l.line_number == inv_line_number}
            next unless invoice_line

            invoice_line.visa_number = nil_blank line["visa no"]
            invoice_line.visa_quantity = nil_blank line["visa qty"], true
            invoice_line.visa_uom = nil_blank line["visa uom"]
            invoice_line.customs_line_number = nil_blank line["customs line number"], true
           
            line_data[:tariffs].values.each do |tariff_line|
              # We don't actually get the underlying Alliance tariff line number in the webtracking files.  Although it's rare,
              # there are some cases where the same tariff number is used on multiple tariff lines for the same com inv. line.
              # In that case, see if we can use tariff line number as an array 
              lines = invoice_line.commercial_invoice_tariffs.find_all {|t| t.hts_code == tariff_line["tariff no"]}
              invoice_tariff_line = nil

              if lines.length == 1
                invoice_tariff_line = lines.first
              elsif lines.length > 1
                invoice_tariff_line = lines[tariff_line["tariff line no"].to_i - 1]
              end

              next unless invoice_tariff_line
              invoice_tariff_line.quota_category = nil_blank tariff_line["category"], true
              # See note by invoice_line.save! below
              invoice_tariff_line.save!
            end

            # Normally, I'd just assume that saving the parent would propigate down and save invoices and 
            # invoice lines and tariff records.  It doesn't appear that ActiveRecrod actually works that way
            # though.  Because we're not setting any invoice fields, it hits the invoice association and then
            # doesn't bother to traverse down to the invoice line level for the update.  Because of that
            # we have to call save on each individual lines/tariffs we update.
            invoice_line.save!
          end
        end

        entry.save!
        outer_entry = entry
      end

      # we want this outside the main transaction otherwise any event listeners will run inside the transaction
      # which we don't want since that will extend the life of the transaction possibly for a long time.
      outer_entry.broadcast_event :save if outer_entry
    end

    private 

    def extract_invoice_information_from_query_lines results
      invoices = {}
      results.each do |line|
        # Strip all line values, Alliance uses char fields instead of varchar ones so fields are all space padded to full
        # db column widths.
        line.values.each {|v| v.strip! if v.respond_to?(:strip)}

        if invoices[line["invoice number"]].nil?
          invoices[line["invoice number"]] = {}
          invoices[line["invoice number"]][:header] = line 
          invoices[line["invoice number"]][:lines] = {}
        end
        
        if invoices[line["invoice number"]][:lines][line["line number"]].nil?
          invoices[line["invoice number"]][:lines][line["line number"]] = {}
          invoices[line["invoice number"]][:lines][line["line number"]][:line] = line
          invoices[line["invoice number"]][:lines][line["line number"]][:tariffs] = {}
        end

        invoices[line["invoice number"]][:lines][line["line number"]][:tariffs][line["tariff line no"]] = line
      end
      invoices
    end

    def nil_blank v, numeric = false
      if numeric
        v.to_i.nonzero? ? v : nil
      else
        v.blank? ? nil : v
      end
    end

    def extract_entry_information lines
      # really, this should always be the first line, but it's just as easy to iterate over the lines and find it
      sh00_line = lines.find {|l| l[0, 4] == "SH00"}
      info = {}
      if sh00_line
        info[:broker_reference] = sh00_line[4,10].gsub(/^[0]*/,'')
        info[:last_exported_from_source] = parse_date_time(sh00_line[24,12])
      end
      
      info
    end

    def find_and_process_entry entry_information
      entry = nil
      Lock.acquire(Lock::ALLIANCE_PARSER, times: 3) do
        entry = Entry.where(broker_reference: entry_information[:broker_reference], source_system: SOURCE_CODE).first_or_create! last_exported_from_source: entry_information[:last_exported_from_source]

        if skip_file? entry, entry_information[:last_exported_from_source]
          entry = nil
        end
      end

      # entry will be nil if we're skipping the file do to it being outdated
      if entry 
        Lock.with_lock_retry(entry) do
          # The lock call here can potentially update us with new data, so we need to check again that another process isn't processing a newer file
          yield entry unless skip_file?(entry, entry_information[:last_exported_from_source])
        end
      end
    end

    def skip_file? entry, last_exported_from_source
      entry && entry.last_exported_from_source && entry.last_exported_from_source > last_exported_from_source
    end

    # header
    def process_sh00 r
      clear_dates

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
      @entry.location_of_goods = r[231, 4].strip
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
      @entry.bond_type = r[491,1].strip
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
      accumulate_string :commercial_invoice_number, @c_invoice.invoice_number

      invoice_value = parse_currency r[50,13]
      @c_invoice.invoice_value = invoice_value
      @entry.total_invoiced_value += parse_currency r[50,13]
    end

    # commercial invoice header optional data
    def process_ci01 r
      # Just straight parse this field as a BigDecimal, we'll want to keep the full value the user input here.
      # This field doesn't not have an implicit decimal value like others in this file (if it even supports one at all, 
      # which isn't real clear)
      @c_invoice.total_quantity = BigDecimal.new r[4, 12]
      @c_invoice.total_quantity_uom = r[16, 6].strip
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
      @c_line.contract_amount = parse_currency r[135,10]
      @c_line.department = r[147,6].strip
      @c_line.product_line = r[230, 30].strip
      @c_line.computed_value = parse_currency r[260,13]
      @c_line.computed_adjustments = parse_currency r[299,13]
      @c_line.computed_net_value = parse_currency r[312,13]
      accumulate_string :export_country_codes, @c_line.country_export_code
      accumulate_string :origin_country_codes, @c_line.country_origin_code
      accumulate_string :vendor_names, @c_line.vendor_name 
      accumulate_string :total_units_uoms, @c_line.unit_of_measure 
      accumulate_string :po_numbers, r[180,35].strip
      accumulate_string :part_numbers, @c_line.part_number
      @entry.total_units += @c_line.quantity 
    end

    def process_cl01 line
      @c_line.line_number = (parse_decimal(line[430, 5], 0) / 10).to_i
    end

    # commercial invoice line - fees
    def process_cf00 r
      val = parse_currency r[7,11]
      case r[4,3]
        when '499'
          @c_line.mpf = val
          if r[29,11] == '00000000000'
            @c_line.prorated_mpf = @c_line.mpf
          else
            @c_line.prorated_mpf = parse_currency r[29,11]
          end
        when '501'
          @c_line.hmf = val
        when '056'
          @c_line.cotton_fee = val
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

    def process_cp00 r
      # There's technically two types of cp00 lines.  Ones for ADD (Anti-Dumping Duty) and CVD (Countervailing Duty)
      # The line positions and field names are identical in each, they just go into different prefix'ed fields based on       
      # the line type
      values = {}
      values[:case_number] = r[8, 9]
      values[:bond] = ((r[32, 1] == "Y") ? true : false)
      values[:duty_amount] = parse_currency r[34, 10]
      values[:case_value] = parse_currency r[17, 10]
      values[:case_percent] = parse_decimal r[27, 5], 2

      type = r[4, 3]
      if type == "ADA"
        @c_line.add_case_number = values[:case_number]
        @c_line.add_bond = values[:bond]
        @c_line.add_duty_amount = values[:duty_amount]
        @c_line.add_case_value = values[:case_value]
        @c_line.add_case_percent = values[:case_percent]
      elsif type == "CVD"
        @c_line.cvd_case_number = values[:case_number]
        @c_line.cvd_bond = values[:bond]
        @c_line.cvd_duty_amount = values[:duty_amount]
        @c_line.cvd_case_value = values[:case_value]
        @c_line.cvd_case_percent = values[:case_percent]
      end
    end

    # invoice header
    def process_ih00 r
      @invoice = @entry.broker_invoices.build(:suffix=>r[4,2],:currency=>"USD")
      @invoice.invoice_number = "#{@entry.broker_reference}#{@invoice.suffix}"
      @invoice.source_system = @entry.source_system
      @invoice.broker_reference = @entry.broker_reference
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
      line.charge_description = "NO DESCRIPTION" if line.charge_description.blank?
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
      it_date = parse_date(r[98,8].strip)
      if it_date 
        if @entry.first_it_date.blank? || @entry.first_it_date > it_date
          @entry.first_it_date = it_date
        end
      end
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
      # create the container record
      c = @entry.containers.build
      c.container_number = r[4,15].strip
      c.goods_description = r[19,40].strip
      c.container_size = r[59,7].strip
      c.weight = r[66,12]
      c.quantity = r[78,12]
      c.uom = r[90,6].strip
      if r.size > 240
        c.seal_number = r[241,15].strip
        c.fcl_lcl = r[271]
        c.size_description = r[283,40].strip
        c.teus = r[323,4]
      else
        c.size_description = ''
      end

      # handle the aggregate fields for the header
      accumulate_string :container_numbers, c.container_number 
      cont_size_num = c.container_size 
      cont_size_desc = c.size_description 
      accumulate_string :container_sizes, (cont_size_desc.blank? ? cont_size_num : "#{cont_size_num}-#{cont_size_desc}")
      accumulate_string :fcl_lcl, r[271] unless r[271].blank?


    end
    
    #comments
    def process_sn00 r
      body = r[4,60].strip
      generated_at = parse_date_time(r[64,12])
      @entry.entry_comments.build(:body=>body,:username=>r[79,12].strip,:generated_at=>generated_at)
      if body.include? "Document Image created for F7501F"
        @entry.first_7501_print = generated_at if @entry.first_7501_print.nil? || generated_at < @entry.first_7501_print
        @entry.last_7501_print = generated_at if @entry.last_7501_print.nil? || generated_at > @entry.last_7501_print
      end
    end

    # make port code nil if all zeros
    def port_code v
      v.blank? || v.match(/^[0]*$/) ? nil : v
    end

    # match importer_id
    def set_importer_id 
      raise "Alliance entry received without customer number" unless @entry.customer_number
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

    def clear_dates
      DATE_MAP.values.each {|v| @entry[v] = nil}
    end
    def parse_date str
      return nil if str.blank? || str.match(/^[0]*$/)
      Date.parse str
    end

    def parse_date_time str
      return nil if str.blank? || str.match(/^[0]*$/)
      begin
        timezone.parse str
      rescue 
        # For some reason Alliance will send us dates with a 60 in the minutes columns (rather than adding an hour)
        # .ie  201305152260
        if str =~ /60$/
          time = timezone.parse(str[0..-3] + "00")
          time + 1.hour
        end
      end
    end

    def timezone
      ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
    end

    def parse_decimal str, decimal_places
      # If the decimal string already has a period in it, don't insert another into it, just parse as is
      if str && str =~ /\./
        d = BigDecimal.new str
        # Make sure we're rounding the value to the specified decimal places (otherwise, the string may be 1.2345 and we may only want 1.23)
        d.round(decimal_places, BigDecimal::ROUND_HALF_UP)
      else
        offset = -(decimal_places+1)
        # NOTE: I don't think this call is doing what was thought it was doing when initially programmed.  The 
        # second argument to new is the # significant digits which is not the same as # of decimal places to use.
        # I'm hesitant to change though, since this has been in place for a while.
        BigDecimal.new str.insert(offset,"."), decimal_places
      end
      
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
