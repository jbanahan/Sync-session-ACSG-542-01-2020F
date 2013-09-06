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
      '490' => :docs_received_date_first,
      '10' => :eta_date=
    }

    SUPPORTING_LINE_TYPES = ['SD', 'CCN', 'CON', 'BL']

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
          supporting_line_type = SUPPORTING_LINE_TYPES.include?(line[0])
          next if (line.size < 10 && !supporting_line_type) || line[0]=='Barcode'
          
          # We'll never encounter a situation where if we have a "new-style" line type where we need to start
          # a new entry.  Therefore, don't even consider creating a new entry unless we have an old-style header
          # line or a new style header
          if !supporting_line_type
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
          end

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
      @entry = process_header lines.first, find_source_system_export_time(s3_path)

      # If the parse header returned nil, it means we shouldn't continue parsing the files lines
      return if @entry.nil?

      lines.each do |line| 

        case line[0]
        when "SD"
          process_activity_line line, accumulated_dates
        when "CCN"
          process_cargo_control_line line
        when "CON"
          process_container_line line
        when "BL"
          process_bill_of_lading_line line
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
      @entry.master_bills_of_lading = retrieve_valid_bills_of_lading
      @entry.container_numbers = accumulated_string(:container_numbers)
      # There's no House bill field in the spec, so we're using the container
      # number field on Air entries to send the data.
      # 1 = Air
      # 2 = Highway (Truck)
      # 6 = Rail
      # 9 = Maritime (Ocean)
      if ["1", "2"].include? @entry.transport_mode_code
        @entry.house_bills_of_lading = accumulated_string(:container_numbers)
      end
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

    def process_header line, current_export_date
      entry_number = str_val(line[0])
      file_number = line[1]
      tax_id = str_val line[3]
      importer_name = str_val line[108]
      entry = find_entry file_number, entry_number, tax_id, importer_name, current_export_date

      return if entry.nil?

      # Shell records won't have broker references, so make sure to set it
      entry.broker_reference = file_number

      #clear commercial invoices
      entry.commercial_invoices.destroy_all

      entry.entry_number = entry_number
      entry.import_country = Country.find_by_iso_code('CA')
      entry.importer_tax_id = tax_id
      accumulate_string :cargo_control_number, str_val(line[12])
      accumulate_string :master_bills_of_lading, str_val(line[13])
      accumulate_string :container_numbers, str_val(line[8])
      entry.ship_terms = str_val(line[17]) {|val| val.upcase}
      entry.direct_shipment_date = parse_date(line[42])
      entry.transport_mode_code = str_val(line[4])
      entry.entry_port_code = str_val(line[5])
      entry.carrier_code = str_val(line[6])
      entry.voyage = str_val(line[7])
      entry.us_exit_port_code = str_val(line[9]) {|us_exit| us_exit.blank? ? us_exit : us_exit.rjust(4,'0')}
      entry.entry_type = str_val(line[10])
      entry.duty_due_date = parse_date(line[56])
      entry.entry_filed_date = entry.across_sent_date = parse_date_time(line, 57)
      entry.first_release_date = entry.pars_ack_date = parse_date_time(line,59)
      entry.pars_reject_date = parse_date_time(line,61) 
      entry.release_date = parse_date_time(line,65)
      entry.cadex_accept_date = parse_date_time(line,67)
      entry.cadex_sent_date = parse_date_time(line,69)
      entry.release_type = str_val(line[89])
      entry.employee_name = str_val(line[88])
      entry.po_numbers = str_val(line[14])
      file_logged_str = str_val(line[94])
      if file_logged_str && file_logged_str.length==10
        entry.file_logged_date = parse_date_time([file_logged_str,"12:00am"],0)
      end
      entry.customer_name = importer_name
      entry.customer_number = str_val line[107]

      entry
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
      t.classification_qty_1 = dec_val(line[31])
      t.classification_uom_1 = str_val(line[32]) 
      t.value_for_duty_code = str_val(line[33])
      t.entered_value = dec_val(line[45])
      @total_entered_value += t.entered_value if t.entered_value
      # For duty rate, we'll either get the specific duty rate (ie. 1.45 / KG) OR
      # the advalorem rate (ie. 5% of Entered Value).  Ad Val rate is the overwhelming
      # majority case.  However, Fenix sends us ad val rates as whole number values 
      # (5.55% instead of .0555) and specific rates as the plain rates....we want ad val rates to be stored 
      # as decimal quantities so the rates are equivalent to how alliance is storing the data.
      # So, we'll use the quantity * duty rate and value * (duty rate / 100) and see which 
      # amount is closer to the actual value sent before setting the value.  Ad Val wins if
      # there's any ambiguity.
      # I ruled out looking up the tariff record and seeing what it says for calculating the duty
      # because we'd run into possible issues when re-running older entry data files and rates have been 
      # changed.

      t.duty_amount = dec_val(line[47])

      duty_rate = dec_val(line[46])
      if duty_rate.try(:nonzero?) && t.entered_value.try(:nonzero?)
        adjusted_duty_rate = (duty_rate / BigDecimal(100))

        # if no classification quantity was present we'll assume we got an adval rate
        if t.classification_qty_1.try(:nonzero?)
          ad_val = t.entered_value * adjusted_duty_rate
          specific_duty = t.classification_qty_1 * duty_rate

          # Just figure out whatever is closest to the actual reported duty amount, which will tell us 
          # whether we need to use the adjusted amount or not
          vals = [(t.duty_amount - ad_val).abs, (t.duty_amount - specific_duty).abs]
          
          if ad_val.nonzero? && vals.min == vals[0]
            t.duty_rate = adjusted_duty_rate
          else
            t.duty_rate = duty_rate
          end
        else
          t.duty_rate = adjusted_duty_rate
        end

      else
        t.duty_rate = duty_rate
      end

      @total_duty += t.duty_amount if t.duty_amount
      t.gst_rate_code = str_val(line[48])
      t.gst_amount = dec_val(line[49])
      @total_gst += t.gst_amount if t.gst_amount
      t.sima_amount = dec_val(line[50])
      t.excise_rate_code = str_val(line[51])
      t.excise_amount = dec_val(line[52])
    end

    def process_activity_line line, accumulated_dates
      if !line[2].nil? && !line[3].nil? && ACTIVITY_DATE_MAP[line[2].strip]
        # We may get just a date here (not date and time)
        time = Time.strptime(line[3] + line[4], "%Y%m%d%H%M") rescue nil
        unless time
          time = Date.strptime(line[3], '%Y%m%d') # we actually want this to fail..it means we're getting bad data
        end
        # This assumes we're using a hash with a default return value of an empty array
        if time
          accumulated_dates[ACTIVITY_DATE_MAP[line[2].strip]] << ((time.is_a?(Date)) ? time : time.in_time_zone(time_zone))
        end
      end
      rescue
    end

    def process_cargo_control_line line
      accumulate_string(:cargo_control_number, line[2]) unless line[2].blank?
    end

    def process_container_line line
      accumulate_string(:container_numbers, line[2]) unless line[2].blank?
    end

    def process_bill_of_lading_line line
      accumulate_string(:master_bills_of_lading, line[2]) unless line[2].blank?
    end

    def retrieve_valid_bills_of_lading 
      # For some reason, RL needs to use abnormally long master bill numbers that are 
      # too long for Fenix to handle.  These numbers are going to come through at the "header"
      # level but will be truncated versions of the real values that will be coming through
      # at the BL line level.

      # Basically, to combat this situation, if one of our master bills is 15 chars (max bill length in fenix)
      # and is a subsequence of one of the others, then we're going to not use it.
      master_bills = @accumulated_strings[:master_bills_of_lading].to_a
      master_bills = master_bills.find_all {|bol| bol.length < 15 || !master_bills.any? {|super_bol| bol != super_bol && super_bol.start_with?(bol)}}
      master_bills.join("\n ")
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
      dt = nil
      if !line[start_pos].blank?
        # If the time component is missing, just set the time to midnight 
        # (Fenix omits time for some entry type / date field combinations and sends it for others)
        time = (line[start_pos+1].blank? ? "12:00am" : line[start_pos+1])
        dt = time_zone.parse_us_base_format("#{line[start_pos]} #{time}") rescue nil
      end
      return dt
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
        if entry.respond_to?(date_setter) && date_array.length > 0
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
    def importer tax_id, importer_name
      if importer_name.blank?
        importer_name = tax_id
      end

      c = Company.where(:fenix_customer_number=>tax_id).first_or_create!(:name=>importer_name, :importer=>true)

      # Change the importer account's name to be the actual name if it's currently the tax id.
      # This code can be taken out at some point in the future when we've updated all/most of the existing importer
      # records.
      if c && tax_id != importer_name && c.name == tax_id
        c.name = importer_name
        c.save!
      end
      c
    end

    def find_entry file_number, entry_number, tax_id, importer_name, source_system_export_date
      # Make sure we aquire a cross process lock to prevent multiple job queues from executing this 
      # at the same time (prevents duplicate entries from being created).
      Lock.acquire(Lock::FENIX_PARSER_LOCK) do 
        entry = Entry.find_by_broker_reference_and_source_system file_number, SOURCE_CODE

        # Because the Fenix shell records created by the imaging client only have an entry number in them,
        # we also have to double check if this file data matches to one of those shell records before 
        # creating a new Entry record.
        if entry.nil?
          entry = Entry.find_by_entry_number_and_source_system entry_number, SOURCE_CODE 
        end

        if entry.nil?
          # Create a shell entry right now to help prevent concurrent job queues from tripping over eachother and
          # creating duplicate records.  We should probably implement a locking structure to make this bullet proof though.
          entry = Entry.create!(:broker_reference=>file_number, :entry_number=> entry_number, :source_system=>SOURCE_CODE,:importer_id=>importer(tax_id, importer_name).id, :last_exported_from_source=>source_system_export_date) 
        elsif source_system_export_date
          # Make sure we also update the source system export date while locked too so we prevent other processes from 
          # processing the same entry with stale data.

          # We want to utilize the last exported from source date to determine if the
          # file we're processing is stale / out of date or if we should process it

          # If the entry has an exported from source date, then we're skipping any file that doesn't have an exported date or has a date prior to the
          # current entry's (entries may have nil exported dates if they were created by the imaging client)
          if entry.last_exported_from_source.nil? || (entry.last_exported_from_source <= source_system_export_date)
            entry.update_attributes(:last_exported_from_source=>source_system_export_date)
          else
            entry = nil
          end
        end

        entry
      end
    end

    def find_source_system_export_time file_path
      return if file_path.blank?

      export_time = nil
      file_name = File.basename(file_path)

      # The b3 filenames are expected to be like b3_detail_acc_111468_201305221506.1369249786.csv, 
      # or b3_detail_rns_109757_201305241527.1369423822.csv.  We're looking to extract the
      # file timestamp value after the last underscore and prior to the .

      # The actual timestamp values are a little funky...they're the date followed by the # of seconds 
      # since midnight of the date (.ie 2013052939266 -> Date = 2013-05-29 Seconds => 39266)
      if file_name =~ /^.+_.+_.+_.+_(\d{8})(\d*)\..+\..+$/
        export_time = time_zone.parse $1
        # Second argument is the radix (to avoid ruby interpretting leading zeros as binary or hex values)
        export_time = export_time + Integer($2, 10).seconds
      end

      export_time
    end
  end
end
