require 'open_chain/integration_client_parser'
module OpenChain
  class FenixParser
    extend OpenChain::IntegrationClientParser
    SOURCE_CODE = 'Fenix'

    def self.integration_folder
      "/opt/wftpserver/ftproot/www-vfitrack-net/_fenix"
    end
    # take the text from a Fenix CSV output file a create entries
    def self.parse file_content, opts={}
      begin
        entry_lines = []
        current_file_number = ""
        CSV.parse(file_content) do |line|
          # Skip any lines that come from the new style of entry lines
          next if line.size < 10 || line[0]=='Barcode' || ['B3L', 'SD', 'CCN', 'CON'].include?(line[0])
          file_number = line[1]
          if !entry_lines.empty? && file_number!=current_file_number
            FenixParser.new.parse_entry entry_lines, opts 
            entry_lines = []
          end
          current_file_number = file_number
          entry_lines << line
        end
        FenixParser.new.parse_entry entry_lines, opts unless entry_lines.empty?
      rescue
        puts $!
        puts $!.backtrace
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

      #get header info from first line
      process_header lines.first
      lines.each do |x| 
        process_invoice x
        process_invoice_line x
      end
      detail_pos = accumulated_string(:po_number)
      @entry.last_file_bucket = s3_bucket
      @entry.last_file_path = s3_path
      @entry.total_invoiced_value = @total_invoice_val
      @entry.total_units = @total_units
      @entry.total_duty = @total_duty
      @entry.total_gst = @total_gst
      @entry.total_duty_gst = @total_duty + @total_gst
      @entry.po_numbers = detail_pos unless detail_pos.blank?
      @entry.master_bills_of_lading = accumulated_string(:bol)
      @entry.container_numbers = accumulated_string(:cont)
      @entry.origin_country_codes = accumulated_string(:org_country)
      @entry.origin_state_codes = accumulated_string(:org_state)
      @entry.export_country_codes = accumulated_string(:exp_country)
      @entry.export_state_codes = accumulated_string(:exp_state)
      @entry.vendor_names = accumulated_string(:vend)
      @entry.part_numbers = accumulated_string(:part_number)
      @entry.commercial_invoice_numbers = accumulated_string(:invoice_number)
      @entry.entered_value = @total_entered_value

      @entry.file_logged_date = time_zone.now.midnight if @entry.file_logged_date.nil?

      @commercial_invoices.each do |inv_num, inv|
        inv.invoice_value = @ci_invoice_val[inv_num]
      end

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
      @entry.cargo_control_number = str_val(line[12])
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
      accumulate_string :vend, ci.vendor_name
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
      accumulate_string :po_number, inv_ln.po_number unless inv_ln.po_number.blank?
      accumulate_string :bol, str_val(line[13])
      accumulate_string :cont, str_val(line[8])
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
      Date.strptime d.strip, '%m/%d/%Y'
    end

    def parse_date_time line, start_pos
      return nil if line[start_pos].blank? || line[start_pos+1].blank?
      time_zone.parse_us_base_format "#{line[start_pos]} #{line[start_pos+1]}"
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
