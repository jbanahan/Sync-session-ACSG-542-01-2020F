require 'open_chain/integration_client_parser'
require 'open_chain/fenix_sql_proxy_client'
require 'open_chain/ftp_file_support'
require 'open_chain/fiscal_month_assigner'
require 'open_chain/custom_handler/entry_parser_support'

module OpenChain; class FenixParser
  include OpenChain::IntegrationClientParser
  include OpenChain::FtpFileSupport
  include OpenChain::CustomHandler::EntryParserSupport

  SOURCE_CODE ||= Entry::FENIX_SOURCE_SYSTEM

  # You can easily add new simple date mappings from the SD records by adding a
  # Activity # -> method name symbol in the entry.
  # ie. 'ABC' => :abc_date
  ACTIVITY_DATE_MAP ||= {
    # Because there's special handling associated with these fields, some of these
    # mapped values intentially use symbols that don't map to actual entry property setter methods
    '180' => :do_issued_date_first,
    '490' => :docs_received_date_first,
    '10' => :eta_date=,
    '868' => :release_date=,
    '1270' => :cadex_sent_date=,
    '1274' => :cadex_accept_date=,
    '1276' => :exam_ordered_date=,
    '1280' => :k84_receive_date=,
    '105'=> :b3_print_date=,
    'DOGIVEN' => :do_issued_date_first,
    'DOCREQ' => {datatype: :date, setter: :docs_received_date_first},
    'ETA' => {datatype: :date, setter: :eta_date=},
    'RNSCUSREL' => :release_date=,
    'CADXTRAN' => :cadex_sent_date=,
    'CADXACCP' => :cadex_accept_date=,
    'ACSREFF' => :exam_ordered_date=,
    'CADK84REC' => {datatype: :date, setter: :k84_receive_date=},
    'B3P' => :b3_print_date=,
    'KPIDOC' => :documentation_request_date=,
    'KPIPO' => :po_request_date=,
    'KPIHTS' => :tariff_request_date=,
    'KPIOGD' => :ogd_request_date=,
    'KPIVAL' => :value_currency_request_date=,
    'KPIPART' => :part_number_request_date=,
    'KPIIOR' => :importer_request_date=,
    "MANINFREC" => :manifest_info_received_date=,
    "SPLITSHPT" => :split_shipment_date=,
    "ACSDECACCP" => :across_declaration_accepted=
  }

  SUPPORTING_LINE_TYPES ||= ['SD', 'CCN', 'CON', 'BL', 'B3D']
  LVS_LINE_TYPE ||= "LVS"

  def self.integration_folder
    ["www-vfitrack-net/_fenix", "/home/ubuntu/ftproot/chainroot/www-vfitrack-net/_fenix"]
  end

  # Due to volume concerns, entries received by this class are not recorded in the inbound file table.
  def self.log_file? bucket, key
    false
  end

  def self.parse_lvs_query_results result_set
    results = result_set.is_a?(String) ? ActiveSupport::JSON.decode(result_set) : result_set

    # In almost all cases, the same summary entry will be used...there's no point in
    # looking them up every time, so just look up on cache misses
    entry_cache = Hash.new do |h, k|
      h[k] = Entry.where(entry_number: k, source_system: SOURCE_CODE).first
    end
    # This is another optimization...no use looking up the CA country every time when we
    # can do it once and provide it to the method
    canada = Country.find_by_iso_code('CA')

    parser = self.new
    results.each do |result|
      child_entry = result['child']

      # For whatever reason, the transaction number in Fenix ND has a space at the end of it in the database
      parent_entry = entry_cache[result['summary'].to_s.strip]

      if parent_entry
        parser.update_lvs_dates parent_entry, result['child'].to_s.strip, canada
      end
    end
  end

  # take the text from a Fenix CSV output file and create entries
  def self.parse file_content, opts={}
    begin
      entry_lines = []
      current_file_number = ""
      file_content.force_encoding "Windows-1252"
      CSV.parse(file_content) do |row|
        # The file we get from Fenix uses Windows "ASNSI" encoding, we want to transcode it to UTF-8
        line = row.map {|r| r.encode("UTF-8", undef: :replace, invalid: :replace, replace: "?") if r }
        if line[0] == "T"
          opts[:timestamp] = parse_timestamp line
          next
        end

        # The "supporting" lines in the new format all have less than 10 file positions
        # So, don't skip the line if we're proc'ing one of those.
        supporting_line_type = SUPPORTING_LINE_TYPES.include?(line[0])

        # LVS Lines have < 10 indexes so we can't skip those either
        next if (line.size < 10 && (!supporting_line_type && line[0] != LVS_LINE_TYPE)) || line[0]=='Barcode'

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

        entry_lines << line
      end
      FenixParser.new.parse_entry entry_lines, opts unless entry_lines.empty?
    rescue
      # The logging here obscures issues in non-production environments (.ie specs) and we don't really
      # care about lock wait errors because these are run in delayed jobs and they'll get picked up
      # later and reprocessed
      raise $! if Rails.env != 'production' || Lock.lock_wait_timeout?($!)

      tmp = Tempfile.new(['fenix_error_', '.txt'])
      tmp << file_content
      tmp.flush
      $!.log_me ["Fenix parser failure."], [tmp.path]
    end
  end

  def parse_entry lines, opts = {}
    s3_bucket = opts[:bucket]
    s3_path = opts[:key]
    start_time = Time.now
    @entry = nil
    @commercial_invoices = {}
    @total_invoice_val = BigDecimal('0.00')
    @total_units = BigDecimal('0.00')
    @total_entered_value = BigDecimal('0.00')
    @total_gst = BigDecimal('0.00')
    @total_duty = BigDecimal('0.00')
    @max_line_number = 0

    if lines.first[0] == LVS_LINE_TYPE
      process_lvs_entry lines
      nil
    else
      accumulated_dates = Hash.new {|h, k| h[k] = []}

      # Gather entry header information needed to find the entry
      info = entry_information strip_b3_from_line(lines.first)

      # The very first B3 for an entry record from Fenix appears to have all zeros as the transaction/entry number.
      # This causes issues with our shell image matching, so we'll just skip these as we should be getting B3's
      # with valid entry numbers shortly
      return nil unless valid_entry_number? info[:entry_number]

      fenix_nd_entry = !opts[:timestamp].nil?

      find_and_process_entry(info[:broker_reference], info[:entry_number], info[:importer_tax_id], info[:importer_name], find_source_system_export_time(s3_path, opts[:timestamp]), fenix_nd_entry) do |entry|
        # Entry is only yieled here if we need to process one (ie. it's not outdated)
        # This whole block is also already inside a transaction, so no need to bother with opening another one
        @entry = entry

        process_header strip_b3_from_line(lines.first), entry

        current_invoice_line = nil
        lines.each do |line|

          case line[0]
          when "SD"
            process_activity_line entry, line, accumulated_dates
          when "CCN"
            process_cargo_control_line line
          when "CON"
            process_container_line line
          when "BL"
            process_bill_of_lading_line line
          when "B3D"
            process_line_detail_line line, current_invoice_line
          else
            line = strip_b3_from_line(line)
            process_invoice line
            current_invoice_line = process_invoice_line line, fenix_nd_entry
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
        @entry.summary_line_count = @max_line_number
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
        @entry.customer_references = accumulated_string(:customer_references)
        @entry.entered_value = @total_entered_value

        @entry.file_logged_date = time_zone.now.midnight if @entry.file_logged_date.nil?

        @commercial_invoices.each do |inv_num, inv|
          inv.invoice_value_foreign = @ci_invoice_val[inv_num]
          inv.invoice_value = inv.invoice_value_foreign * inv.exchange_rate
        end

        set_entry_dates @entry, accumulated_dates

        begin
          OpenChain::FiscalMonthAssigner.assign @entry
        rescue FiscalDateError => e
          # If the fiscal date is missing, then log it so we know there's an issue...but we don't want that to actually bomb
          # the entry load.
          e.log_me
        end

        @entry.save!
        # match up any broker invoices that might have already been loaded
        @entry.link_broker_invoices
        # write time to process without reprocessing hooks
        @entry.update_column(:time_to_process, ((Time.now-start_time) * 1000).to_i)

        # F type entries are LVS Summaries...when we get one of these we then want to request a full listing of any of the "child" LVS
        # transaction numbers so we can pull the summary level dates down into the child entries.
        if summary_entry_type? @entry
          OpenChain::FenixSqlProxyClient.new.delay.request_lvs_child_transactions @entry.entry_number
        end

        @entry.create_snapshot User.integration

        forward_entry_data @entry.customer_number, opts[:timestamp], File.basename(s3_path.to_s), lines
      end
      nil
    end
  end

  def update_lvs_dates parent_entry, child_transaction, import_country = nil
    child_entry = nil
    Lock.acquire("Entry-#{SOURCE_CODE}-#{child_transaction}") do
      # Individual B3 lines will come through for these entries, at that point, they'll set the importer and other information
      # LV is the fenix entry type for Low-Value entries.
      child_entry = Entry.where(:entry_number => child_transaction, :source_system => SOURCE_CODE).first_or_create! :import_country => import_country, entry_type: "LV"
    end

    child_entry.release_date = parent_entry.release_date
    child_entry.cadex_sent_date = parent_entry.cadex_sent_date
    child_entry.cadex_accept_date = parent_entry.cadex_accept_date
    child_entry.k84_receive_date = parent_entry.k84_receive_date

    child_entry.save!
  end

  def ftp_credentials
    # We'll give the actual folder above, so don't bother defining here
    ecs_connect_vfitrack_net(nil)
  end

  class HoldReleaseSetter
    attr_accessor :entry

    def initialize ent
      @entry = ent
    end

    def set_on_hold
      entry.on_hold = entry.hold_date && !entry.hold_release_date ? true : false
    end

    def set_hold_date
      entry.hold_date = entry.exam_ordered_date
    end

    def set_hold_release_date
      entry.hold_release_date = entry.exam_release_date = entry.release_date
    end
  end

  private

  def self.parse_timestamp line
    time_zone.parse(line[1].to_s+line[2].to_s.rjust(6, "0"))
  end
  private_class_method :parse_timestamp

  def entry_information line
    {
      :entry_number =>  str_val(line[0]),
      :broker_reference => line[1],
      :importer_tax_id => str_val(line[3]),
      :importer_name => str_val(line[108])
    }
  end

  def strip_b3_from_line line
    line[0].to_s.strip == "B3L" ? line[1..-1] : line
  end

  def process_header line, entry
    info = entry_information(line)

    # Shell records won't have broker references, so make sure to set it
    entry.broker_reference = info[:broker_reference]

    entry.entry_number = info[:entry_number]
    entry.broker = find_ca_broker entry.entry_number
    entry.import_country = Country.find_by_iso_code('CA')
    entry.importer_tax_id = info[:importer_tax_id]
    accumulate_string :cargo_control_number, str_val(line[12])
    accumulate_string :master_bills_of_lading, str_val(line[13])
    accumulate_string :container_numbers, str_val(line[8])
    entry.ship_terms = str_val(line[17]) {|val| val.upcase}
    entry.direct_shipment_date = parse_date(line[42])
    entry.transport_mode_code = str_val(line[4])
    entry.entry_port_code = prep_port_code(str_val(line[5]))
    entry.carrier_code = str_val(line[6])
    entry.carrier_name = str_val line[97]
    entry.voyage = str_val(line[7])
    entry.us_exit_port_code = str_val(line[9]) {|us_exit| us_exit.blank? ? us_exit : us_exit.rjust(4, '0')}
    entry.entry_type = str_val(line[10])
    entry.duty_due_date = parse_date(line[56])
    entry.entry_filed_date = entry.across_sent_date = parse_date_time(line, 57)
    entry.first_release_date = entry.pars_ack_date = parse_date_time(line, 59)
    entry.pars_reject_date = parse_date_time(line, 61)

    # We get 3 date values via a separate LVS file feed from Fenix for low-value entries
    # These are K84 Receive Date, Release Date, and Cadex Accept.
    # A b3 file generally follows the LVS file, but it likely doesn't have any of these
    # date values, so we don't want to blank them out if the LVS came through.
    # If the K84 Receive date has been set, then we've received the LVS file for an entry,
    # In these cases the release date and cadex date should only update the entry if they
    # have a value in them

    if entry.k84_receive_date.nil?
      entry.release_date = parse_date_time(line, 65)
      entry.cadex_accept_date = parse_date_time(line, 67)
      entry.cadex_sent_date = parse_date_time(line, 69)
    else
      entry.release_date = ((dt = parse_date_time(line, 65)).blank? ? entry.release_date : dt)
      entry.cadex_accept_date = ((dt = parse_date_time(line, 67)).blank? ? entry.cadex_accept_date : dt)
      entry.cadex_sent_date = ((dt = parse_date_time(line, 69)).blank? ? entry.cadex_sent_date : dt)
    end

    entry.release_type = str_val(line[89])
    entry.employee_name = str_val(line[88])
    entry.po_numbers = str_val(line[14])
    file_logged_str = str_val(line[94])
    if file_logged_str && file_logged_str.length==10
      entry.file_logged_date = parse_date_time([file_logged_str, "12:00am"], 0)
    end
    entry.customer_name = info[:importer_name]
    entry.customer_number = str_val line[107]
    entry.total_packages = int_val line[109]
    entry.total_packages_uom = "PKGS" unless entry.total_packages.blank?
    entry.gross_weight = int_val line[110]
    entry.ult_consignee_name = str_val line[98]

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
    # Fenix ND sometimes doesn't send the exchange rate when the currency is Canadian
    ci.exchange_rate = dec_val(line[44])
    if ci.exchange_rate.blank?
      if ci.currency == "CAD"
        ci.exchange_rate = 1
      else
        raise "File # / Invoice # #{@entry.broker_reference} / #{ci.invoice_number} was missing an exchange rate.  Exchange rate must be present for commercial invoices where the currency is not CAD."
      end
    end

    ci.mfid = str_val(line[102])
    accumulate_string :vendor_names, ci.vendor_name
    accumulate_string :invoice_number, ci.invoice_number
  end

  def process_invoice_line line, fenix_nd = true
    inv = @commercial_invoices[line[15]]
    # inv will be blank if there was no invoice information on the line
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
    inv_ln.customer_reference = line[103] unless line[103].blank?
    inv_ln.customs_line_number = int_val(line[92])
    @max_line_number = inv_ln.customs_line_number if inv_ln.customs_line_number.to_i > @max_line_number
    inv_ln.subheader_number = int_val(line[93])
    inv_ln.add_to_make_amount = BigDecimal.new(0)
    inv_ln.miscellaneous_discount = BigDecimal.new(0)
    accumulate_string :exp_country, exp[0]
    accumulate_string :exp_state, exp[1]
    accumulate_string :org_country, org[0]
    accumulate_string :org_state, org[1]
    accumulate_string :customer_references, inv_ln.customer_reference

    if fenix_nd
      inv_ln.adjustments_amount = dec_val(line[113])
    else
      total_value_with_adjustments = dec_val(line[105])

      if total_value_with_adjustments
        adjustments_per_piece = dec_val(line[113])
        total_value_with_adjustments += adjustments_per_piece if adjustments_per_piece
        inv_ln.adjustments_amount = total_value_with_adjustments - (inv_ln.value ? inv_ln.value : BigDecimal.new("0"))
      end
    end

    t = inv_ln.commercial_invoice_tariffs.build
    t.spi_primary = str_val(line[28])
    str_val(line[29]) do |hts_code|
      t.hts_code = hts_code.gsub('.', '').length < 10 ? "0#{hts_code}" : hts_code
    end

    t.tariff_provision = str_val(line[30])
    t.classification_qty_1 = dec_val(line[31])
    t.classification_uom_1 = str_val(line[32])
    t.value_for_duty_code = str_val(line[33])
    t.special_authority = str_val(line[34])
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
    if duty_rate.try(:nonzero?) && t.entered_value.try(:nonzero?) && t.duty_amount.try(:nonzero?)
      adjusted_duty_rate = (duty_rate / BigDecimal(100))

      # if no classification quantity was present we'll assume we got an adval rate
      if t.classification_qty_1.try(:nonzero?)
        ad_val = t.entered_value * adjusted_duty_rate
        specific_duty = t.classification_qty_1 * duty_rate

        # Just figure out whatever is closest to the actual reported duty amount, which will tell us
        # whether we need to use the adjusted amount or not
        vals = [(t.duty_amount - ad_val).abs, (t.duty_amount - specific_duty).abs]

        # When doing the calculations this way, there's actually the possibility due to some rounding involved
        # in calculating the duty amount that the specific calculation MAY be more exact by a fraction of a cent
        # - even when the adval rate is the effective rate.
        # If this is the case, prefer the adval rate, since it's the overwhelmingly used scenario.

        if ad_val.nonzero? && (vals.min == vals[0] || ((vals[0] - vals[1]).abs <= BigDecimal("0.01")))
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
    t.sima_code = str_val(line[35])
    t.excise_rate_code = str_val(line[51])
    t.excise_amount = dec_val(line[52])
    t.tariff_description = line[24]

    inv_ln
  end

  def process_activity_line entry, line, accumulated_dates
    data = date_map_data line[2].to_s.strip
    if !line[3].blank? && data
      if line[4].blank? || data[:datatype] == :date
        time = time_zone.parse(line[3]).to_date rescue nil
      else
        time = time_zone.parse("#{line[3]}#{line[4]}") rescue nil
      end

      # This assumes we're using a hash with a default return value of an empty array
      if time
        accumulated_dates[data[:setter]] << time
      end
    end

    # We're not capturing the date from Event 5, but we need to pull the employee code from it
    if !line[5].blank?
      case line[2].to_s.strip
      when "5", "SHPCR"
        # Capture the employee name that opened the file (Event 5 is File Opened)
        entry.employee_name = line[5]
      end
    end

    nil
    rescue
  end

  def date_map_data date_key
    values = ACTIVITY_DATE_MAP[date_key]
    if values && !values.is_a?(Hash)
      values = {datatype: :datetime, setter: values}
    end
    values
  end

  def update_hold_summaries entry
    hrss = OpenChain::FenixParser::HoldReleaseSetter.new entry
    hrss.set_hold_date
    hrss.set_hold_release_date
    hrss.set_on_hold
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
    self.class.time_zone
  end

  def self.time_zone
    ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
  end

  def country_state str
    return ["US", str[1, 2]] if str && str.length==3 && str[0]="U"
    return [str, nil]
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

    # For F type entries (which are the "parent" entries of the LV (low value) entries), CA customs doesn't issue
    # a traditional release date for them.  At least one customer is bothered that these entries
    # never show release, so to appease them we're going to take the Cadex Accept (which is filled in) and set that as
    # the release date.
    if summary_entry_type? entry
      entry.release_date = entry.cadex_accept_date
    end

    # Default the arrival date to the release date.  (SOW 1691)
    entry.arrival_date = entry.release_date

    update_hold_summaries entry
  end

  def accumulated_string string_code
    return "" unless @accumulated_strings && @accumulated_strings[string_code]
    @accumulated_strings[string_code].to_a.join("\n ")
  end

  def importer tax_id, importer_name
    importer_name = tax_id if importer_name.blank?

    c = Company.find_or_create_company!("Fenix", tax_id, {name: importer_name, importer: true, fenix_customer_number: tax_id})

    # Change the importer account's name to be the actual name if it's currently the tax id.
    # This code can be taken out at some point in the future when we've updated all/most of the existing importer
    # records.
    if c && tax_id != importer_name && c.name == tax_id
      c.name = importer_name
      c.save!
    end
    c
  end

  def find_and_process_entry file_number, entry_number, tax_id, importer_name, source_system_export_date, fenix_nd_entry = false
    # Make sure we aquire a cross process lock to prevent multiple job queues from executing this
    # at the same time (prevents duplicate entries from being created).
    entry = nil
    importer = nil
    shell_entry = nil
    Lock.acquire("Entry-#{SOURCE_CODE}-#{file_number}") do
      break if Entry.purged? SOURCE_CODE, file_number, source_system_export_date

      entry = Entry.find_by_broker_reference_and_source_system file_number, SOURCE_CODE

      # Because the Fenix shell records created by the imaging client only have an entry number in them,
      # we also have to double check if this file data matches to one of those shell records before
      # creating a new Entry record.
      if entry.nil?
        entry = Entry.find_by_entry_number_and_source_system entry_number, SOURCE_CODE
      else
        # See if there's a related "shell" entry in the system.  These are left behind and missed by the entry number/source system
        # query above if the b3 from Fenix comes over initially w/ a blank entry number (seems to be fairly common).
        # If left alone we then end up w/ duplicate entries..one regular one, and one shell one.
        shell_entry = Entry.where(broker_reference: nil, source_system: SOURCE_CODE, entry_number: entry_number).first
      end

      # This call may create new importers, so we want it inside our parser lock block
      importer = importer(tax_id, importer_name)

      if entry.nil?
        # Create a shell entry right now to help prevent concurrent job queues from tripping over eachother and
        # creating duplicate records.  We should probably implement a locking structure to make this bullet proof though.
        entry = Entry.create!(:broker_reference=>file_number, :entry_number=> entry_number, :source_system=>SOURCE_CODE, :importer_id=>importer.id, :last_exported_from_source=>source_system_export_date)
      end

      if fenix_nd_entry
        if !validate_no_transaction_reuse(entry, file_number)
          # Set the entry and shell_entry to nil if the transaction is being reused...we don't want to update any data in it.
          entry = nil
          shell_entry = nil
        end
      end
    end

    # The is a bit of an optimization..there's no point waiting on the
    # lock if we're just going to abort because we're looking at old data
    if shell_entry || (entry && process_file?(entry, source_system_export_date))

      # Once we've got the entry we're looking for we'll lock it for updates so we don't have
      # a really course grained lock in place while we're updating some values in the entry to prep
      # it for replacement.  By locking the entry here, we can ensure that only a single instance
      # of the parser will run the updates in here at a single time.

      # Be careful, the with_lock call actually reloads the entry object's data
      # That's why the last exported check is in here since time spent waiting on this
      # lock may have resulting in a more updated version of the entry coming in.
      Lock.with_lock_retry(entry) do
        if source_system_export_date
          # Make sure we also update the source system export date while locked too so we prevent other processes from
          # processing the same entry with stale data.

          # We want to utilize the last exported from source date to determine if the
          # file we're processing is stale / out of date or if we should process it

          # If the entry has an exported from source date, then we're skipping any file that doesn't have an exported date or has a date prior to the
          # current entry's (entries may have nil exported dates if they were created by the imaging client)
          if shell_entry || process_file?(entry, source_system_export_date)
            entry.update_attributes(:last_exported_from_source=>source_system_export_date)
          else
            break
          end
        end

        # Fenix can actually change the importer the entry is associated with so we need to handle updating the importer as well.
        # Not sure if this is an operational error or if its something like pre-keying invoice data prior to actually knowing what
        # entity is importing the goods.  Either way we need to make sure the entry is associated with the correct importer company
        if importer && importer.id != entry.importer_id
          entry.importer = importer
        end

        if shell_entry
          begin
            Lock.with_lock_retry(shell_entry) do
              # Our new entry will always have an id set at this point, so we can just go ahead and set all attachments to it (avoid n+1 situation)
              shell_entry.attachments.update_all attachable_id: entry.id
              # If we don't reload the attachments after moving them to the other entry, then the destroy call below will
              # go through and delete the attachments still since they're still referenced in memory to the shell entry.
              shell_entry.attachments.reload
              entry.attachments.reload
              # There's no need for the shell entry, so just delete it.
              shell_entry.destroy
            end
          rescue ActiveRecord::RecordNotFound
            # don't care..just means another process already handled removing the shell record...that's fine.
          end
        end

        # Destroy invoices since the file we get is a full replacement of the invoice values, not an update.
        # Large entries with lots of invoices can take quite a while to delete (upwards of a minute), which may result in other processes
        # timing out with a lock wait error - hence the lock_rety.  Even if there's some timeouts, at least the
        # files will get reparsed via delayed job retries.
        entry.commercial_invoices.destroy_all

        yield entry
      end

      # Broadcast the save event outside the locks.  No need for any business logic running to generate
      # stuff from the file to contribute to the transaction length here.  Most logic should be delayed
      # out to a background queue anyway.
      entry.broadcast_event :save
    end

    nil
  end

  def process_lvs_entry lines
    # We're going to force any created entry to be canadian origin, which will force them to show on screen
    # on the Canadian entry view.
    canada = Country.find_by_iso_code('CA')

    # Extract all the activity lines for each child entry listed, then we can use the standard set_entry_dates method to fill the date values
    accumulated_entry_dates = {}
    lines.each do |line|
      accumulated_entry_dates[line[2]] ||= {}
      date_key = ACTIVITY_DATE_MAP[line[3]]
      if date_key
        accumulated_entry_dates[line[2]][date_key] ||= []
        # parse date time above expects times in MM/dd/yyyy format
        accumulated_entry_dates[line[2]][date_key] << time_zone.parse(line[4])
      end
    end

    accumulated_entry_dates.each do |entry_number, dates|
      entry = nil
      Lock.acquire("Entry-#{SOURCE_CODE}-#{entry_number}") do
        # Individual B3 lines will come through for these entries, at that point, they'll set the importer and other information
        entry = Entry.where(:entry_number => entry_number, :source_system => SOURCE_CODE).first_or_create! :import_country => canada
      end

      set_entry_dates entry, dates
      entry.save!
    end
  end

  def process_file? entry, source_system_export_date
    entry.last_exported_from_source.nil? || (entry.last_exported_from_source <= source_system_export_date)
  end

  def find_source_system_export_time file_path, timestamp
    # For the new B3 records coming from Fenix ND there's a T record at the top of the file that gives us the export timestamp...use that instead
    return timestamp unless timestamp.nil?
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

  def valid_entry_number? number
    # Match anything that's got 1-9 in it somewhere
    (number =~ /[1-9]/) != nil
  end

  def prep_port_code str
    return nil if str.blank?
    r = str
    while r.length < 4
      r = "0#{r}"
    end
    r
  end

  def validate_no_transaction_reuse entry, new_file_number
    if entry.release_date && entry.release_date < time_zone.parse("2015-09-18")
      subject = "Transaction # #{entry.entry_number} cannot be reused in Fenix ND"
      message = "Transaction # #{entry.entry_number} / File # #{new_file_number} has been used previously in old Fenix as File # #{entry.broker_reference}. Please correct this Fenix ND file and resend to VFI Track."
      m = OpenMailer.send_simple_html(Group.use_system_group("fenix_admin", name: "Fenix Admin"), subject, message)
      m.deliver_now if Array.wrap(m.to).length > 0

      false
    else
      true
    end
  end

  def forward_entry_data customer_number, timestamp, filename, lines
    # Manually reprocessing could mean these values don't get sent through, in which case skip the forwarding
    return if timestamp.nil? || filename.blank?

    # The main (www) instance of VFI Track forwards on these B3 files to different systems.
    # Ideally, this would happen at a higher application stack level than this, by reading the B3 files
    # determining which customers need the data forwarded and then doing that, but we're kind of stuck doing
    # it here due to some limitations in our B2B application.
    ftp_folders = forwarding_config[customer_number]

    # Allow a single string or array of folders to forward the data to
    if !ftp_folders.nil?
      # Ideally we can just sent the same tempfile multiple times, if set up to forward,
      # but something in the ftp process is closing the file (I think it's the paperclip
      # process when saving the ftp session).  So, just build / recreate the tempfile multiple
      # times
      Array.wrap(ftp_folders).each do |folder|
        Tempfile.open(["fenix-b3", ".csv"]) do |temp|
          temp.binmode
          temp << timestamp_csv(timestamp).to_csv
          lines.each {|line| temp << line.to_csv }
          temp.flush
          temp.rewind
          Attachment.add_original_filename_method(temp, filename)
          ftp_file temp, folder: folder, keep_local: true
        end
      end
    end
  end

  def timestamp_csv timestamp
    time = timestamp.in_time_zone(time_zone)
    ["T", time.strftime("%Y%m%d"), time.strftime("%H%M%S")]
  end

  def forwarding_config
    c = MasterSetup.secrets["fenix_b3_forwarding"]
    c.nil? ? {} : c
  end

  def summary_entry_type? entry
    entry.entry_type.to_s.upcase == "F"
  end

  def process_line_detail_line line, invoice_line
    amount = dec_val(line[3])
    if amount && invoice_line
      if amount < 0
        invoice_line.miscellaneous_discount += -amount
      elsif amount > 0
        invoice_line.add_to_make_amount += amount
      end
    end
  end

end; end
