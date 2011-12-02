require 'bigdecimal'
module OpenChain
  class AllianceParser

    DATE_MAP = {'00012'=>:arrival_date,
      '00016'=>:entry_filed_date,
      '00019'=>:release_date,
      '99202'=>:first_release_date,
      '00052'=>:free_date,
      '00028'=>:last_billed_date,
      '00032'=>:invoice_paid_date,
      '00044'=>:liquidation_date,
      '00042'=>:duty_due_date,
      '00001'=>:export_date
    }
    # take the text inside an internet tracking file from alliance and create/update the entry
    def self.parse file_content
      begin
        entry_lines = []
        file_content.lines.each do |line|
          prefix = line[0,4]
          if !entry_lines.empty? && prefix=="SH00"
            AllianceParser.new.parse_entry entry_lines 
            entry_lines = []
          end
          entry_lines << line
        end
        AllianceParser.new.parse_entry entry_lines if !entry_lines.empty?
      rescue
        tmp = Tempfile.new('alliance_error')
        tmp << file_content
        tmp.flush
        $!.log_me ["Alliance parser failure."], [tmp.path]
      end
    end

    def parse_entry rows
      Entry.transaction do 
        start_time = Time.now
        rows.each do |r|
          break if @skip_entry
          prefix = r[0,4]
          case prefix
            when "SH00"
              process_sh00 r
            when "SH01"
              process_sh01 r
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
          end
        end
        if !@skip_entry
            @entry.it_numbers = accumulated_string :it_number 
            @entry.master_bills_of_lading = accumulated_string :mbol 
            @entry.house_bills_of_lading = accumulated_string :hbol 
            @entry.sub_house_bills_of_lading = accumulated_string :sub 
            @entry.customer_references = (@accumulated_strings[:cust_ref].to_a - @accumulated_strings[:po_numbers].to_a).join("\n")
            @entry.mfids = accumulated_string :mfid
            @entry.export_country_codes = accumulated_string :export_country_codes
            @entry.origin_country_codes = accumulated_string :origin_country_codes
            @entry.vendor_names = accumulated_string :vendor_names
            @entry.total_units_uoms = accumulated_string :total_units_uoms
            @entry.special_program_indicators = accumulated_string :spis
            @entry.po_numbers = accumulated_string :po_numbers
            @entry.save! if @entry
            #set time to process in milliseconds without calling callbacks
            @entry.connection.execute "UPDATE entries SET time_to_process = #{((Time.now-start_time) * 1000).to_i.to_s} WHERE ID = #{@entry.id}"
        end
        @skip_entry = false
      end
    end

    private 
    # header
    def process_sh00 r
      brok_ref = r[6,8]
      @entry = Entry.find_by_broker_reference brok_ref
      if @entry && @entry.last_exported_from_source && @entry.last_exported_from_source > parse_date_time(r[24,12]) #if current is newer than file
        @skip_entry = true
      else
        @entry = Entry.new(:broker_reference=>brok_ref) unless @entry
        @entry.total_invoiced_value = 0 #reset, then accumulate as we process invoices
        @entry.total_units = 0 #reset, then accumulate as we process invoice lines
        @entry.customer_number = r[14,10].strip
        @entry.last_exported_from_source = parse_date_time r[24,12]
        @entry.company_number = r[36,2].strip
        @entry.division_number = r[38,4].strip
        @entry.customer_name = r[42,35].strip
        @entry.entry_type = r[166,2].strip
        @entry.entry_number = r[168,12]
        @entry.carrier_code = r[225,4].strip
        @entry.total_packages = r[300,12]
        @entry.total_packages_uom = r[312,6].strip
        @entry.merchandise_description = r[77,70].strip
        @entry.transport_mode_code = r[164,2]
        @entry.entry_port_code = r[160,4]
        @entry.ult_consignee_code = r[180,10].strip
        @entry.ult_consignee_name = r[190,35].strip
        @entry.gross_weight = r[318,12]
      end
    end

    # header continuation
    def process_sh01 r
      @entry.total_fees = parse_currency r[85,12]
      @entry.total_duty = parse_currency r[49,12]
      @entry.total_duty_direct = parse_currency r[357,12]
      @entry.entered_value = parse_currency r[384,13]
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
      accumulate_string :mfid, r[96,15].strip
      @entry.total_invoiced_value += parse_currency r[50,13]
    end

    # commercial invoice line
    def process_cl00 r
      accumulate_string :export_country_codes, r[80,2]
      accumulate_string :origin_country_codes, r[67,2]
      accumulate_string :vendor_names, r[83,35].strip
      accumulate_string :total_units_uoms, r[46,6].strip
      accumulate_string :po_numbers, r[180,35].strip
      @entry.total_units += parse_decimal r[34,12], 3 
    end

    # commercial invoice line - tariff
    def process_ct00 r
      accumulate_string :spis, r[29,2].strip
      accumulate_string :spis, r[31].strip
    end

    # invoice header
    def process_ih00 r
      @invoice = nil
      @invoice = @entry.broker_invoices.where(:suffix=>r[4,2]).first if @entry.id  #existing entry, check for existing invoice
      @invoice = @entry.broker_invoices.build(:suffix=>r[4,2]) unless @invoice
      @invoice.invoice_date = parse_date r[6,8]
      @invoice.invoice_total = parse_currency r[24,11]
      @invoice.customer_number = r[14,10].strip
      @invoice.bill_to_name = r[83,35].strip
      @invoice.bill_to_address_1 = r[118,35].strip
      @invoice.bill_to_address_2 = r[153,35].strip
      @invoice.bill_to_city = r[188,35].strip
      @invoice.bill_to_state = r[223,2].strip
      @invoice.bill_to_zip = r[225,9].strip
      @invoice.bill_to_country = Country.find_by_iso_code(r[234,2]) unless r[234,2].strip.blank?
      @invoice.save! unless @invoice.id.blank? #save existing that are updated
      @invoice.broker_invoice_lines.destroy_all
    end

    # invoice line
    def process_il00 r
      line = @invoice.broker_invoice_lines.build
      line.charge_code = r[4,4].strip
      line.charge_description = r[8,35].strip
      line.charge_amount = parse_currency r[43,11]
      line.vendor_name = r[54,30].strip
      line.vendor_reference = r[84,15].strip
      line.charge_type = r[99,1]
      line.save unless @invoice.id.blank?
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

    def parse_date str
      return nil if str.blank?
      Date.parse str
    end
    def parse_date_time str
      return nil if str.blank?
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
      @accumulated_strings[string_code].to_a.join("\n")
    end
  end
end
