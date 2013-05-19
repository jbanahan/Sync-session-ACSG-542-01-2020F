require 'open_chain/integration_client_parser'
module OpenChain
  class FenixParser
    extend OpenChain::IntegrationClientParser
    SOURCE_CODE = 'Fenix'

    # You can easily add new simple date mappings from the SD records by adding a 
    # Activity # -> method name symbol in the entry.
    # ie. 'ABC' => :abc_date 
    ACTIVITY_DATE_MAP = {
      # Because there's special handling associated with these fields, some of these 
      # mapped values intentially use symbols that don't map to actual entry property setter methods
      '180' => :do_issued_date_first,
      '490' => :docs_received_date_first
    }

    SUPPORTING_LINE_TYPES = ['SD', 'CCN', 'CON']

    def self.integration_folder
      "/opt/wftpserver/ftproot/www-vfitrack-net/_fenix"
    end

    # take the text from a Fenix CSV output file a create entries
    def self.parse file_content, opts={}
      begin
        entry_lines = []
        current_file_number = ""
        CSV.parse(file_content) do |line|
          # The "supporting" lines in the new format all have less than 10 file positions 
          # So, don't skip the line if we're proc'ing one of those.
          next if (line.size < 10 && !SUPPORTING_LINE_TYPES.include?(line[0])) || line[0]=='Barcode'
          
          # We're counting on the new-style lines to have a unique value in the barcode field (line[1] in new style)
          # and the old style lines were counting on the file number value being unique (line[1] in old style)
          # These values are never going to be the same for old/new style lines either, so we can safely
          # depend on the value to a unique way to identify new lines, even across new vs. old line styles.
          file_number = line[1]
          if !entry_lines.empty? && file_number!=current_file_number
            FenixParser.new.parse_entry entry_lines, opts 
            entry_lines = []
          end
          current_file_number = file_number

          # The new style header line is exactly the same as the old, except for a leading line identifier
          # value in the first position.  Shift the identifier off so we don't have to bother with different 
          # array indexes between line styles when parsing the entry and invoice data from these lines
          line.shift if line[0] == "B3L"

          entry_lines << line
        end
        FenixParser.new.parse_entry entry_lines, opts unless entry_lines.empty?
      rescue
        tmp = Tempfile.new(['fenix_error_','.txt'])
        tmp << file_content
        tmp.flush
        $!.log_me ["Fenix parser failure."], [tmp.path]
      end
    end

    def parse_entry lines, opts={} 
      s3_bucket = opts[:bucket]
      s3_path = opts[:key]
      start_time = Time.now
      @commercial_invoices = {}
      @total_invoice_val = BigDecimal('0.00')
      @total_units = BigDecimal('0.00')
      @total_entered_value = BigDecimal('0.00')
      @total_gst = BigDecimal('0.00')
      @total_duty = BigDecimal('0.00')

      accumulated_dates = Hash.new {|h, k| h[k] = []}

      #get header info from first line
      process_header lines.first
      lines.each do |line| 

        case line[0]
        when "SD"
          process_activity_line line, accumulated_dates
        when "CCN"
          process_cargo_control_line line
        when "CON"
          process_container_line line
        else 
          process_invoice line
          process_invoice_line line
        end
      end

      detail_pos = accumulated_string(:po_numbers)
      @entry.last_file_bucket = s3_bucket
      @entry.last_file_path = s3_path
      @entry.total_invoiced_value = @total_invoice_val
      @entry.total_units = @total_units
      @entry.total_duty = @total_duty
      @entry.total_gst = @total_gst
      @entry.total_duty_gst = @total_duty + @total_gst
      @entry.po_numbers = detail_pos unless detail_pos.blank?
      @entry.master_bills_of_lading = accumulated_string(:master_bills_of_lading)
      @entry.container_numbers = accumulated_string(:container_numbers)
      @entry.origin_country_codes = accumulated_string(:org_country)
      @entry.origin_state_codes = accumulated_string(:org_state)
      @entry.export_country_codes = accumulated_string(:exp_country)
      @entry.export_state_codes = accumulated_string(:exp_state)
      @entry.vendor_names = accumulated_string(:vendor_names)
      @entry.part_numbers = accumulated_string(:part_number)
      @entry.commercial_invoice_numbers = accumulated_string(:invoice_number)
      @entry.cargo_control_number = accumulated_string(:cargo_control_number)
      @entry.entered_value = @total_entered_value

      @entry.file_logged_date = time_zone.now.midnight if @entry.file_logged_date.nil?

      @commercial_invoices.each do |inv_num, inv|
        inv.invoice_value = @ci_invoice_val[inv_num]
      end

      set_entry_dates @entry, accumulated_dates

      @entry.save!
      #match up any broker invoices that might have already been loaded
      @entry.link_broker_invoices
      #write time to process without reprocessing hooks
      @entry.connection.execute "UPDATE entries SET time_to_process = #{((Time.now-start_time) * 1000).to_i.to_s} WHERE ID = #{@entry.id}"
    end

    private

    def process_header line
      entry_number = str_val(line[0])
      file_number = line[1]
      tax_id = str_val line[3]
      @entry = Entry.find_by_broker_reference_and_source_system file_number, SOURCE_CODE

      # Because the Fenix shell records created by the imaging client only have and entry number in them,
      # we also have to double check if this file data matches to one of those shell records before 
      # creating a new Entry record.
      if @entry.nil?
        @entry = Entry.find_by_entry_number_and_source_system entry_number, SOURCE_CODE

        if @entry.nil?
          @entry = Entry.new(:broker_reference=>file_number,:source_system=>SOURCE_CODE,:importer_id=>importer(tax_id).id) 
        else
          # Shell records won't have broker references, so make sure to set it
          @entry.broker_reference = file_number
        end 
      end
      
      #clear commercial invoices
      @entry.commercial_invoices.destroy_all

      @entry.entry_number = entry_number
      @entry.import_country = Country.find_by_iso_code('CA')
      @entry.importer_tax_id = tax_id
      accumulate_string :cargo_control_number, str_val(line[12])
      accumulate_string :master_bills_of_lading, str_val(line[13])
      accumulate_string :container_numbers, str_val(line[8])
      @entry.ship_terms = str_val(line[17]) {|val| val.upcase}
      @entry.direct_shipment_date = parse_date(line[42])
      @entry.transport_mode_code = str_val(line[4])
      @entry.entry_port_code = str_val(line[5])
      @entry.carrier_code = str_val(line[6])
      @entry.voyage = str_val(line[7])
      @entry.us_exit_port_code = str_val(line[9]) {|us_exit| us_exit.blank? ? us_exit : us_exit.rjust(4,'0')}
      @entry.entry_type = str_val(line[10])
      @entry.duty_due_date = parse_date(line[56])
      @entry.entry_filed_date = @entry.across_sent_date = parse_date_time(line, 57)
      @entry.first_release_date = @entry.pars_ack_date = parse_date_time(line,59)
      @entry.pars_reject_date = parse_date_time(line,61) 
      @entry.release_date = parse_date_time(line,65)
      @entry.cadex_accept_date = parse_date_time(line,67)
      @entry.cadex_sent_date = parse_date_time(line,69)
      @entry.release_type = str_val(line[89])
      @entry.employee_name = str_val(line[88])
      @entry.po_numbers = str_val(line[14])
      file_logged_str = str_val(line[94])
      if file_logged_str && file_logged_str.length==10
        @entry.file_logged_date = parse_date_time([file_logged_str,"12:00am"],0)
      end
    end

    def process_invoice line
      # Skip invoice lines that don't have invoice numbers
      return if line[16].nil? || line[16].blank?

      @commercial_invoices[line[15]] ||= @entry.commercial_invoices.build
      @ci_line_count ||= {}
      @ci_line_count[line[15]] ||= 0
      @ci_invoice_val ||= {}
      @ci_invoice_val[line[15]] ||= BigDecimal('0.00')
      ci = @commercial_invoices[line[15]]
      ci.invoice_number = str_val(line[16])
      ci.invoice_date = parse_date(line[18])
      ci.vendor_name = str_val(line[11])
      ci.currency = str_val(line[43])
      ci.exchange_rate = dec_val(line[44])
      accumulate_string :vendor_names, ci.vendor_name
      accumulate_string :invoice_number, ci.invoice_number
    end

    def process_invoice_line line
      inv = @commercial_invoices[line[15]]
      #inv will be blank if there was no invoice information on the line
      return if inv.nil?

      inv_ln = inv.commercial_invoice_lines.build
      page_num = str_val(line[21])
      line_num = str_val(line[22])
      @ci_line_count[line[15]] += 1
      inv_ln.line_number = @ci_line_count[line[15]]
      inv_ln.part_number = str_val(line[23])
      inv_ln.po_number = str_val(line[25])
      inv_ln.quantity = dec_val(line[37])
      @total_units += inv_ln.quantity if inv_ln.quantity
      inv_ln.unit_of_measure = str_val(line[38])
      inv_ln.value = dec_val(line[40])
      unless inv_ln.value.nil?
        @ci_invoice_val[line[15]] += inv_ln.value 
        @total_invoice_val ||= BigDecimal('0.00')
        @total_invoice_val += inv_ln.value
      end
      accumulate_string :po_numbers, inv_ln.po_number unless inv_ln.po_number.blank?
      accumulate_string :master_bills_of_lading, str_val(line[13])
      accumulate_string :container_numbers, str_val(line[8])
      accumulate_string :part_number, inv_ln.part_number unless inv_ln.part_number.blank?
      exp = country_state(line[26])
      org = country_state(line[27])
      inv_ln.country_export_code = exp[0]
      inv_ln.state_export_code = exp[1]
      inv_ln.country_origin_code = org[0]
      inv_ln.state_origin_code = org[1]
      inv_ln.unit_price = dec_val(line[39])
      accumulate_string :exp_country, exp[0]
      accumulate_string :exp_state, exp[1]
      accumulate_string :org_country, org[0]
      accumulate_string :org_state, org[1]

      t = inv_ln.commercial_invoice_tariffs.build
      t.spi_primary = str_val(line[28])
      t.hts_code = str_val(line[29])
      t.tariff_provision = str_val(line[30])
      t.classification_qty_1 = int_val(line[31])
      t.classification_uom_1 = str_val(line[32]) 
      t.value_for_duty_code = str_val(line[33])
      t.entered_value = dec_val(line[45])
      @total_entered_value += t.entered_value if t.entered_value
      t.duty_amount = dec_val(line[47])
      @total_duty += t.duty_amount if t.duty_amount
      t.gst_rate_code = str_val(line[48])
      t.gst_amount = dec_val(line[49])
      @total_gst += t.gst_amount if t.gst_amount
      t.sima_amount = dec_val(line[50])
      t.excise_rate_code = str_val(line[51])
      t.excise_amount = dec_val(line[52])
    end

    def process_activity_line line, accumulated_dates
      if !line[2].nil? && !line[3].nil? && !line[4].nil? && ACTIVITY_DATE_MAP[line[2].strip]
        time = Time.strptime(line[3] + line[4], "%Y%m%d%H%M")
        # This assumes we're using a hash with a default return value of an empty array
        accumulated_dates[ACTIVITY_DATE_MAP[line[2].strip]] << time.in_time_zone(time_zone)
      end
      rescue
    end

    def process_cargo_control_line line
      accumulate_string(:cargo_control_number, line[2]) unless line[2].nil?
    end

    def process_container_line line
      accumulate_string(:container_numbers, line[2]) unless line[2].nil?
    end
    
    def dec_val val
      BigDecimal(val) unless val.blank?
    end
    def int_val val
      val.strip.to_i unless val.blank?
    end

    # Evaluates and returns any given block if the value passed in is 
    # not blank or nill.
    def str_val val
      return nil if val.nil? || val.blank?
      if val.match /^[ 0]*$/
        val = ""
      else 
        val = val.strip
      end
      val = yield val if block_given?
      val
    end

    def parse_date d
      return nil if d.blank? 
      Date.strptime(d.strip, '%m/%d/%Y') rescue return nil
    end

    def parse_date_time line, start_pos
      return nil if line[start_pos].blank? || line[start_pos+1].blank?
      time_zone.parse_us_base_format("#{line[start_pos]} #{line[start_pos+1]}") rescue return nil
    end

    def time_zone
      ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
    end

    def country_state str
      return ["US",str[1,2]] if str && str.length==3 && str[0]="U"
      return [str,nil]
    end

    def accumulate_string string_code, value
      @accumulated_strings ||= Hash.new
      @accumulated_strings[string_code] ||= Set.new
      @accumulated_strings[string_code] << value unless value.blank?
    end

    def first_accumulated_date dates, key
      date_list = dates[key]
      date_list ? date_list.first : nil
    end

    def set_entry_dates entry, accumulated_dates
      # The accumulated dates hash is supposed to be a symbol => Activity Date array
      # We're basically just looping through the dates we've processed from SD records
      # and then setting the last SD date value processed from the file into the entry.
      # So in the case of multiple records that have the same code, we're pushing
      # only the last date value into the entry here.

      accumulated_dates.each do |date_setter, date_array|
        if entry.respond_to? date_setter
          entry.send(date_setter, date_array.last)  
        end
      end

      # There's a couple of date values that need special handling beyond just setting the
      # last SD date value from the file.
      entry.first_do_issued_date = first_accumulated_date(accumulated_dates, :do_issued_date_first)
      entry.docs_received_date = first_accumulated_date(accumulated_dates, :docs_received_date_first)
    end

    def accumulated_string string_code
      return "" unless @accumulated_strings && @accumulated_strings[string_code]
      @accumulated_strings[string_code].to_a.join("\n ")
    end
    def importer tax_id
      imp = Company.find_by_fenix_customer_number tax_id
      imp = Company.create!(:name=>tax_id,:fenix_customer_number=>tax_id,:importer=>true) if imp.nil?
      imp
    end
  end
end
