require 'open_chain/sql_proxy_client'
require 'open_chain/s3'
require 'open_chain/integration_client_parser'
require 'open_chain/alliance_imaging_client'

module OpenChain; module CustomHandler; class KewillEntryParser
  extend OpenChain::IntegrationClientParser

  # If no hash value is present, the symbol value component represents the name of the 
  # date attribute that will be set, the datatype is assumed to be a datetime.
  # If a hash value is present, at a minimum, an attribute: key must be set.
  # You may include a datatype: key w/ a value of either date or datetime.
  # Also, you may include a directive: of either :first or :last to specify if
  # the lowest or highest value for the date is kept. 
  DATE_MAP ||= {
    1 => {attribute: :export_date, datatype: :date},
    2 => :bol_received_date,
    3 => {attribute: :docs_received_date, datatype: :date},
    98 => {attribute: :docs_received_date, datatype: :date},
    4 => :file_logged_date,
    9 => {attribute: :first_it_date, datatype: :date, directive: :first},
    10 => :arrival_notice_receipt_date,
    11 => {attribute: :eta_date, datatype: :date},
    12 => :arrival_date,
    19 => :release_date,
    20 => :fda_release_date,
    24 => :trucker_called_date,
    25 => :delivery_order_pickup_date,
    26 => :freight_pickup_date,
    28 => :last_billed_date,
    32 => :invoice_paid_date,
    42 => {attribute: :duty_due_date, datatype: :date},
    44 => {attribute: :liquidation_date, datatype: :date},
    48 => {attribute: :daily_statement_due_date, datatype: :date},
    52 => :free_date,
    85 => {attribute: :edi_received_date, datatype: :date},
    108 => :fda_transmit_date,
    121 => {attribute: :daily_statement_approved_date, datatype: :date},
    2014 => :final_delivery_date,
    2222 => :worksheet_date,
    2223 => :available_date,
    5023 => :cancelled_date,
    92007 => :isf_sent_date,
    92008 => :isf_accepted_date,
    93002 => :fda_review_date,
    99202 => :first_release_date,
    99212 => :first_entry_sent_date,
    99310 => {attribute: :monthly_statement_received_date, datatype: :date},
    99311 => {attribute: :monthly_statement_paid_date, datatype: :date}
  }

  def self.integration_folder
    # This parser is actually used across multiple deployment instances (hm and www.vfitrack.net)
    # and we could conceivable use it for more as well, so make sure the integration folder we're storing
    # to is tied to the system code as well
    "/home/ubuntu/ftproot/chainroot/#{MasterSetup.get.system_code}/_kewill_entry"
  end

  def self.parse json_content, opts={}
    # This is the method that's called by the controller, we'll want to save off the json data it sends
    # first before parsing it, so the data that was exported is archived.
    # Unwrap the data from the outer entity wrapper
    outer = json_content.is_a?(String) ? ActiveSupport::JSON.decode(json_content) : json_content
    json = outer['entry']
    return nil if json.nil?
    
    entry = self.new.process_entry json, opts

    if entry
      # We're setting up a message delay of 5 minutes here because it seems this feed comes across sometimes faster than
      # Kewill Imaging can store off the files locally.  The imaging request gets over to our imaging clients prior to the 
      # image existing in Kewill Imaging and thus we don't get any files back.  So, use :delay_seconds in order to hold back
      # for 5 minutes.
      if MasterSetup.get.custom_feature?("Kewill Imaging")
        # This can actually be removed at some point in the near future once we're sure the Kewill imaging push process is working fine
        # Once it's workign fine, there's no reason at that point to be doing pull requests when the documents should be pushing over just
        # fine...we're just double requesting every file and taxing the system more.  The "Request Images" button will still remain on the
        # entry screen too.
        OpenChain::AllianceImagingClient.request_images(entry.broker_reference, delay_seconds: 300) unless opts[:imaging] == false
      end
      entry.broadcast_event(:save)
    end

    entry
  end

  def self.save_to_s3 entry_data
    json = entry_data['entry']
    return nil if json.nil?

    key = s3_file_path(json)
    bucket = OpenChain::S3.integration_bucket_name
    json_to_tempfile(entry_data) {|f| OpenChain::S3.upload_file(bucket, key, f) }

    {bucket: bucket, key: key}
  end

  def process_entry json, opts={}
    start_time = Time.zone.now
    user = User.integration
    entry = find_and_process_entry(json.with_indifferent_access) do |e, entry|
      begin
        preprocess entry
        process_entry_header e, entry
        process_dates e, entry
        # Liquidation data depends on the presence of the liquidation date
        # So we parse it after we've parsed dates.
        process_liquidation e, entry
        process_notes e, entry
        process_bill_numbers e, entry
        #Process containers before commercial invoices since invoice lines can link to containers
        process_containers e, entry
        process_commercial_invoices e, entry
        process_broker_invoices e, entry
        process_fda_dates e, entry
        
        if opts[:key] && opts[:bucket]
          entry.last_file_path = opts[:key]
          entry.last_file_bucket = opts[:bucket]
        end

        postprocess e, entry

        FiscalMonthAssigner.assign entry

        entry.save!
        entry.update_column :time_to_process, ((Time.now-start_time) * 1000)

        entry.create_snapshot user
        entry
      rescue => e
        raise e unless Rails.env.production?

        # Add the entity wrapper name back in so the data can easily just be passed back through
        # the parser for testing/problem solving
        self.class.json_to_tempfile({"entry" => json}) do |f|
          e.log_me ["Kewill Entry Parser Failure"], [f.path]
        end

        # Make sure if we run into errors that we return nil, otherwise the calling method will broadcast save events on unsaved changes
        entry = nil
      end
    end

    entry
  end

  private 

    def self.json_to_tempfile json
       Tempfile.open([Time.zone.now.iso8601, ".json"]) do |f|
        f << json.to_json
        f.flush
        f.rewind
        yield f
      end
    end

    def find_and_process_entry(e)
      entry = nil 
      file_no, updated_at, extract_time = self.class.entry_info e

      Lock.acquire(Lock::ALLIANCE_PARSER) do
        # Make sure the entry has not been purged. We want to allow for re-using file numbers, so we'll assume that any data exported from the source system AFTER the purge record was created
        # means that the data is for a totally new entry and not for the one that was purged
        break if Entry.purged? Entry::KEWILL_SOURCE_SYSTEM, file_no, extract_time

        entry = Entry.where(broker_reference: file_no, source_system: Entry::KEWILL_SOURCE_SYSTEM).first_or_create! expected_update_time: updated_at, last_exported_from_source: extract_time
        if skip_file? entry, extract_time
          entry = nil
        end
      end

      # entry will be nil if we're skipping the file due to it being outdated
      if entry 
        Lock.with_lock_retry(entry) do
          # The lock call here can potentially update us with new data, so we need to check again that another process isn't processing a newer file
          if !skip_file?(entry, extract_time)
            entry.expected_update_time = updated_at
            entry.last_exported_from_source = extract_time
            return yield e, entry
          end
        end
      end
    end

    def skip_file? entry, last_exported_from_source
       # Skip if the last exported from source value is newer than the file's value
      entry && entry.last_exported_from_source && entry.last_exported_from_source > last_exported_from_source
    end

    def self.entry_info e
      [e['file_no'].to_s, parse_numeric_datetime(e['updated_at']), tz.parse(e['extract_time'])]
    end

    def self.s3_file_path e
      # File No and Extract Time should never, ever be missing
      file_no, updated_at, extract_time = entry_info e

      # Every other file has the file dates in the path based on UTC, so we're just going to 
      # continue doing that here too.
      now = Time.zone.now.in_time_zone("UTC")
      "#{now.strftime("%Y-%m/%d")}#{integration_folder}/#{file_no}-#{extract_time.strftime("%Y-%m-%d-%H-%M")}.json"
    end

    def preprocess entry
      entry.total_invoiced_value = 0
      entry.broker_invoice_total = 0
      entry.total_units = 0
      entry.total_add = 0
      entry.total_cvd = 0
      entry.total_packages = 0
      entry.fda_pending_release_line_count = 0

      # Clear dates
      attributes = {}
      DATE_MAP.keys.each do |v|
        c = get_date_config v
        next unless c 
        # Don't clear anything w/ a first/last/ifnull directive, since we want to retain those original dates
        next unless c[:directive] == :none
        attributes[c[:attribute]] = nil
      end
      entry.assign_attributes attributes
      nil
    end

    # Any sort of post-handling of the data that needs to be done prior to saving belongs in this method
    def postprocess e, entry
      entry.monthly_statement_due_date = find_statement_due_date(e, entry)

      process_totals e, entry
    end

    def find_statement_due_date e, entry
      due_date = nil

       # I'm not entirely sure why you'd have a periodic statement due date, where you don't have a statement number
      # but the old feed did this too, so I'm keeping it in place
      pms_year = e[:pms_year]
      pms_month = e[:pms_month]
      pms_day = nil
      if pms_year.try(:nonzero?) && pms_month.try(:nonzero?)
        dates = KeyJsonItem.usc_periodic_dates(pms_year).first
        if dates
          #JSON keys are always strings
          pms_day = dates.data[pms_month.to_s]
        end

        # We're only currently tracking pms days since 2007, if we don't have a date after that time..then error
        # so that we can set up the schedule

        # The entry filed date check is here because the ISF system creates shell entry records with Arrival Dates sometimes months 
        # in advance - which is valid.  However, the presence of the arrival date also then triggers an attempt to determine a statement
        # date - which at this point in time is pointless as nothing has actually been filed for the entry yet and PMS statement dates may not 
        # have even been published yet US CBP.  So wait till there's an entry filed date to bother reporting on the missing PMS values
        if pms_day.nil? && pms_year > 2006 && !entry.entry_filed_date.nil?
          StandardError.new("File ##{entry.broker_reference} / Division ##{entry.division_number}: No Periodic Monthly Statement Dates found for #{pms_year} and #{pms_month}.  This data must be set up immediately.").log_me
        end
      end

      pms_day ? Date.new(pms_year, pms_month, pms_day) : nil
    end

    def process_entry_header e, entry
      entry.customer_number = e[:cust_no]
      entry.entry_number = e[:entry_no]
      entry.customer_number = e[:cust_no]
      entry.importer_tax_id = e[:irs_no]
      entry.customer_name = e[:cust_name]
      entry.importer = get_importer entry.customer_number, entry.customer_name
      entry.merchandise_description = e[:desc_of_goods]

      entry.entry_port_code = port_code e[:port_entry]
      entry.lading_port_code = port_code e[:port_lading]
      entry.unlading_port_code = port_code e[:port_unlading]
      entry.destination_state = e[:destination_state]
      entry.entry_type = e[:entry_type].to_s.rjust(2, '0')

      entry.voyage = e[:voyage_flight_no]
      entry.vessel = e[:vessel_airline_name]
      entry.location_of_goods = e[:location]
      entry.location_of_goods_description = e[:location_of_goods]

      entry.ult_consignee_code = e[:uc_no]
      entry.ult_consignee_name = e[:uc_name]
      entry.consignee_address_1 = e[:uc_address_1]
      entry.consignee_address_2 = e[:uc_address_2]
      entry.consignee_city = e[:uc_city]
      entry.consignee_state = e[:uc_state]
      entry.transport_mode_code = e[:mot].to_s.rjust(2, '0')
      entry.carrier_code = e[:carrier]
      entry.carrier_name = e[:carrier_name]
      entry.company_number = e[:company_no].to_s.rjust(2, '0')
      entry.division_number = e[:division_no].to_s.rjust(4, '0')

      recon_flags = []
      recon_flags << "NAFTA" unless (e[:recon_nafta].blank? || e[:recon_nafta].to_s.upcase == "N")
      recon_flags << "VALUE" unless (e[:recon_value].blank? || e[:recon_value].to_s.upcase == "N")
      recon_flags << "CLASS" unless (e[:recon_class].blank? || e[:recon_class].to_s.upcase == "N")
      recon_flags << "9802" unless (e[:recon_9802].blank? || e[:recon_9802].to_s.upcase == "N")

      entry.recon_flags = (recon_flags.length > 0 ? recon_flags.join(" ") : nil)
      entry.total_packages = e[:piece_count]
      entry.total_packages_uom = e[:piece_count_uom]
      entry.total_fees = parse_decimal(e[:fees_tot])
      entry.total_duty = parse_decimal(e[:duty_tot])
      entry.total_duty_direct = parse_decimal(e[:duty_paid_direct_amt])
      entry.entered_value = parse_decimal(e[:value_entered])
      entry.hmf = parse_decimal(e[:hmf_tot]).nonzero?
      entry.mpf = parse_decimal(e[:mpf_tot]).nonzero?
      entry.cotton_fee = parse_decimal(e[:cotton_tot]).nonzero?

      entry.gross_weight = parse_decimal(e[:weight_gross], decimal_places: 0, decimal_offset: 0).to_i

      entry.pay_type = e[:abi_payment_type]

      
      statement_no = e[:statement_no]
      daily_statement_no = e[:daily_statement_no]
      # statement_no contains either the periodic statement or the daily statement no
      # depending on if the values match or not
      if daily_statement_no != statement_no
        entry.daily_statement_number = daily_statement_no
        entry.monthly_statement_number = statement_no
      else
        entry.daily_statement_number = daily_statement_no
        entry.monthly_statement_number = nil
      end

      entry.census_warning = e[:census_warning].to_s.upcase == "Y"
      entry.error_free_release = e[:error_free_cr].to_s.upcase == "Y"
      entry.paperless_certification = e[:certification_es].to_s.upcase == "Y"
      entry.paperless_release = e[:paperless_es].to_s.upcase == "Y"
      
      entry.final_statement_date = parse_numeric_date e[:final_stmnt_rcvd]

      entry.release_cert_message = e[:cr_certification_output_mess]
      entry.fda_message = e[:fda_output_mess]
      # Bond Types are defaulted to broker specified one if the value in the entry data specifies 8
      entry.bond_type = e[:bond_type] == 8 ? e[:broker_bond_type] : e[:bond_type]
      entry.import_country = Country.where(iso_code: "US").first

      nil
    end

    def process_liquidation e, entry
      if entry.liquidation_date && Time.zone.now.to_date >= entry.liquidation_date.in_time_zone(tz).to_date
        entry.liquidation_type_code = e[:type_liquidation].to_s.rjust(2, '0')
        entry.liquidation_type = e[:liquidation_type_desc]
        entry.liquidation_action_code = e[:action_liquidation].to_s.rjust(2, '0')
        entry.liquidation_action_description = e[:liquidation_action_desc]
        entry.liquidation_extension_code = e[:extend_suspend_liq].to_s.rjust(2, '0')
        entry.liquidation_extension_description = e[:extension_suspension_desc]
        entry.liquidation_extension_count = parse_decimal(e[:no_extend_suspend_liquidation], decimal_places: 0, decimal_offset: 0).to_i
        entry.liquidation_duty = parse_decimal e[:duty_amt_liquidated]
        entry.liquidation_fees = parse_decimal e[:fee_amt_liquidated]
        entry.liquidation_tax = parse_decimal e[:tax_amt_liquidated]
        entry.liquidation_ada = parse_decimal e[:ada_amt_liquidated]
        entry.liquidation_cvd = parse_decimal e[:cvd_amt_liquidated]
        entry.liquidation_total = entry.liquidation_duty + entry.liquidation_fees + entry.liquidation_tax + entry.liquidation_ada + entry.liquidation_cvd
      end
    end

    def process_totals e, entry
      accumulations = Hash.new do |h, k|
        h[k] = Set.new
      end

      totals = Hash.new do |h, k|
        h[k] = BigDecimal.new(0)
      end

      entry.commercial_invoices.each do |ci|
        accumulations[:commercial_invoice_numbers] << ci.invoice_number
        totals[:total_invoiced_value] += ci.invoice_value_foreign unless ci.invoice_value_foreign.nil?
        totals[:total_non_dutiable_amount] += ci.non_dutiable_amount unless ci.non_dutiable_amount.nil?
        accumulations[:total_packages_uom] << ci.total_quantity_uom

        ci.commercial_invoice_lines.each do |il|
          accumulations[:mids] << il.mid
          accumulations[:country_export_codes] << il.country_export_code
          accumulations[:country_origin_code] << il.country_origin_code
          accumulations[:vendor_names] << il.vendor_name 
          accumulations[:total_units_uoms] << il.unit_of_measure
          accumulations[:po_numbers] << il.po_number
          accumulations[:part_numbers] << il.part_number
          accumulations[:departments] << il.department
          accumulations[:store_names] << il.store_name
          accumulations[:product_lines] << il.product_line
          totals[:total_units] += il.quantity unless il.quantity.nil?
          totals[:total_cvd] += il.cvd_duty_amount unless il.cvd_duty_amount.nil?
          totals[:total_add] += il.add_duty_amount unless il.add_duty_amount.nil?
          totals[:other_fees] += il.other_fees unless il.other_fees.nil?

          il.commercial_invoice_tariffs.each do |cit|
            accumulations[:spis] << cit.spi_primary
            accumulations[:spis] << cit.spi_secondary
          end
        end
      end

      entry.broker_invoices.each do |bi|
        next if bi.destroyed? || bi.marked_for_destruction?

        totals[:broker_invoice_total] += bi.invoice_total unless bi.invoice_total.nil?
        bi.broker_invoice_lines.each do |bil|
          accumulations[:charge_codes] << bil.charge_code
        end
      end

      entry.containers.each do |c|
        accumulations[:container_numbers] << c.container_number
        accumulations[:container_sizes] << (c.size_description.blank? ? c.container_size.to_s : "#{c.container_size}-#{c.size_description}")
        accumulations[:fcl_lcls] << c.fcl_lcl
      end
      
      Array.wrap(e[:cust_refs]).each {|ref| accumulations[:customer_references] << ref[:cust_ref]}
      Array.wrap(e[:broker_invoices]).each {|bi| accumulations[:customer_references] << bi[:cust_ref]}

      # The dup is here so we can iterate over values while still inserting/reading
      # from the primary hash (inserts happen due to the default hash behavior we've 
      # added)
      accumulations.dup.each_pair do |k, v|
        vals = accumulated(accumulations, k)
        case k
        when :customer_references
          # Remove any ref that's also listed as a PO
          pos = accumulations[:po_numbers].to_a.select {|v| !v.blank? }
          refs = accumulations[:customer_references].to_a.select {|v| !v.blank? }
          entry.customer_references = (refs - pos).join("\n ")
        when :commercial_invoice_numbers
          entry.commercial_invoice_numbers = vals
        when :mids
          entry.mfids = vals
        when :country_export_codes
          entry.export_country_codes = vals
        when :country_origin_code
          entry.origin_country_codes = vals
        when :vendor_names
          entry.vendor_names = vals
        when :total_units_uoms
          entry.total_units_uoms = vals
        when :spis
          entry.special_program_indicators = vals
        when :po_numbers
          entry.po_numbers = vals
        when :part_numbers
          entry.part_numbers = vals
        when :container_numbers
          entry.container_numbers = vals
        when :container_sizes
          entry.container_sizes = vals
        when :charge_codes
          entry.charge_codes = vals
        when :commercial_invoice_numbers
          entry.commercial_invoice_numbers = vals
        when :departments
          entry.departments = vals
        when :store_names
          entry.store_names = vals
        when :fcl_lcls
          entry.fcl_lcl = v.size > 1 ? "Mixed" : (v.first.upcase == "L" ? "LCL" : "FCL") unless v.blank?
        when :product_lines
          entry.product_lines = vals
        end
      end

      totals.each_pair do |key, value|
        case key
        when :total_invoiced_value
          entry.total_invoiced_value = value
        when :broker_invoice_total
          entry.broker_invoice_total = value
        when :total_units
          entry.total_units = value
        when :total_cvd
          entry.total_cvd = value if value.nonzero?
        when :total_add
          entry.total_add = value if value.nonzero?
        when :total_non_dutiable_amount
          entry.total_non_dutiable_amount = value if value.nonzero?
        when :other_fees
          entry.other_fees = value if value.nonzero?
        end
      end

      entry.fda_pending_release_line_count = pending_fda_release_line_count entry
      nil
    end

    def accumulated hash, key
      hash[key].keep_if {|v| !v.blank? }.to_a.join "\n "
    end

    def process_notes e, entry
      entry.entry_comments.destroy_all

      customs_response_times = []
      Array.wrap(e[:notes]).each do |n|
        note = n[:note]
        generated_at = parse_numeric_datetime(n[:date_updated])

        comment = entry.entry_comments.build body: n[:note], username: n[:modified_by], generated_at: generated_at
        # The public private flag is set a little wonky because we do a before_save callback as a further step to determine if the 
        # comment should be public or not.  This is skipped if the flag is already set.
        if n[:confidential].to_s.upcase == "Y"
         comment.public_comment = false
        end

        if note.to_s.downcase.include?("document image created for f7501f") || note.to_s.downcase.include?("document image created for form_n7501")
          entry.first_7501_print = earliest_date(entry.first_7501_print, generated_at)
          entry.last_7501_print = latest_date(entry.first_7501_print, generated_at)
        end

        # We're recording the Entry Filed Date as time of the first reponse from customs
        customs_response_times << generated_at if comment.username.to_s.upcase == "CUSTOMS"
      end

      entry.entry_filed_date = (customs_response_times.size > 0 ? customs_response_times.sort.first : nil)

      nil
    end

    def get_date_config date_no
      config = DATE_MAP[date_no]
      out_config = nil
      if config
        default_config = {datatype: :datetime, directive: :none}
        if config.is_a?(Symbol)
          out_config = default_config.merge({attribute: config})
        else
          out_config = default_config.merge config
        end
      end

      out_config
    end

    def process_dates e, entry
      Array.wrap(e[:dates]).each do |date|
        config = get_date_config date[:date_no].to_i
        next unless config

        in_val = (config[:datatype] == :date ? parse_numeric_date(date[:date]) : parse_numeric_datetime(date[:date]))

        val = nil
        case config[:directive]
        when :first
          val = earliest_date(in_val, entry.read_attribute(config[:attribute]))
        when :last
          val = latest_date(in_val, entry.read_attribute(config[:attribute]))
        when :ifnull
          # Only set the date field if the entry hasn't had the value already set
          next unless entry.read_attribute(config[:attribute]).blank?
          val = in_val
        else
          val = in_val
        end

        entry.assign_attributes config[:attribute] => val
      end

      nil
    end

    def process_bill_numbers e, entry
      it_numbers = Set.new
      master_bills = Set.new
      house_bills = Set.new
      subhouse_bills = Set.new
      house_scacs = Set.new

      Array.wrap(e[:ids]).each do |id|
        it_numbers << id[:it_no]
        master_bills << id[:scac].to_s.strip + id[:master_bill].to_s
        house_bills << id[:scac_house].to_s.strip + id[:house_bill].to_s
        subhouse_bills << id[:sub_bill].to_s
        house_scacs << id[:scac_house].to_s.strip unless id[:scac_house].to_s.blank?
      end
      blank = lambda {|d| d.blank?}
      entry.it_numbers = it_numbers.reject(&blank).sort.join("\n ")
      entry.master_bills_of_lading = master_bills.reject(&blank).sort.join("\n ")
      entry.house_bills_of_lading = house_bills.reject(&blank).sort.join("\n ")
      entry.sub_house_bills_of_lading = subhouse_bills.reject(&blank).sort.join("\n ")
      # Technically, based on the DB structure in Kewill, there can be more than 1 house carrier code
      # In practice, according to Mark, that won't happen.  So we're only pulling the first non-blank value encountered.
      entry.house_carrier_code = house_scacs.first
      nil
    end

    def process_commercial_invoices e, entry
      entry.commercial_invoices.destroy_all

      Array.wrap(e[:commercial_invoices]).each do |i|
        invoice = entry.commercial_invoices.build
        set_invoice_header_data i, invoice
        Array.wrap(i[:lines]).each do |l|
          line = invoice.commercial_invoice_lines.build
          set_invoice_line_data l, line, entry

          Array.wrap(l[:tariffs]).each do |t|
            tariff = line.commercial_invoice_tariffs.build
            set_invoice_tariff_data t, tariff

            Array.wrap(t[:lacey]).each do |l|
              lacey = tariff.commercial_invoice_lacey_components.build
              set_lacey_data l, lacey
            end
          end
        end
      end

      nil
    end

    def set_invoice_header_data i, inv
      inv.invoice_number = i[:ci_no]
      inv.currency = i[:currency]
      inv.exchange_rate = parse_decimal i[:exchange_rate], decimal_places: 6, decimal_offset: 6
      inv.invoice_value_foreign = parse_decimal i[:value_foreign]
      inv.country_origin_code = i[:country_origin]
      inv.gross_weight = i[:weight_gross]
      inv.total_charges = parse_decimal i[:charges]
      inv.invoice_date = parse_numeric_date i[:invoice_date]
      # The data on invoice value in Alliance appears to be messed up, we SHOULD be able to 
      # get the invoice_value from the value_us field.  However, that field appears to have
      # conflicting data in it when you actually do the foreign -> US conversion using the 
      # exchange rates.  .ie Invoice Foreign: 1468.80 / Exchange: 1.0818 ...Value US: 1468.80 (????)
      inv.invoice_value = inv.invoice_value_foreign * inv.exchange_rate
      inv.total_quantity = i[:qty]
      inv.total_quantity_uom = i[:qty_uom]
      inv.non_dutiable_amount = parse_decimal(i[:non_dutiable_amt])

      # Find the first line w/ a non-blank mid and use that
      mid = Array.wrap(i[:lines]).find {|l| !l[:mid].blank?}.try(:[], :mid)
      inv.mfid = mid
    end

    def set_invoice_line_data l, line, entry
      line.line_number = l[:ci_line_no].to_i / 10
      line.mid = l[:mid]
      line.part_number = l[:part_no]
      line.po_number = l[:po_no]
      line.quantity = parse_decimal l[:qty], decimal_offset: 3, decimal_places: 3
      line.unit_of_measure = l[:qty_uom]
      line.value = parse_decimal l[:value_us]
      line.country_origin_code = l[:country_origin]
      line.country_export_code = l[:country_export]
      line.related_parties = l[:related_parties].to_s.upcase == "Y"
      line.vendor_name = l[:mid_name]
      line.volume = parse_decimal l[:volume]
      if line.quantity && line.quantity.nonzero? && line.value
        line.unit_price = (line.value / line.quantity).round(2)
      end
      
      # Contract is sent with decimal places, so don't do the offset stuff when parsing
      line.contract_amount = parse_decimal l[:contract], no_offset: true
      line.department = l[:department] unless l[:department].to_s == "0"
      line.store_name = l[:store_no]
      line.product_line = l[:product_line]
      line.visa_number = l[:visa_no]
      line.visa_quantity = parse_decimal(l[:visa_qty]).nonzero?
      line.visa_uom = l[:visa_uom]
      line.customs_line_number = l[:uscs_line_no]
      line.value_foreign = parse_decimal l[:value_foreign]
      line.computed_value = parse_decimal(l[:value_tot]) - parse_decimal(l[:non_dutiable_amt]) - parse_decimal(l[:add_to_make_amt])
      line.computed_adjustments = parse_decimal(l[:non_dutiable_amt]) + parse_decimal(l[:add_to_make_amt]) + parse_decimal(l[:other_amt]) +
                                     parse_decimal(l[:misc_discount]) + parse_decimal(l[:cash_discount]) + parse_decimal(l[:freight_amount])
      line.computed_net_value = parse_decimal(l[:value_tot]) - line.computed_adjustments
      line.first_sale = l[:value_appraisal_method].to_s.upcase == "F"
      line.value_appraisal_method = l[:value_appraisal_method]
      line.non_dutiable_amount = parse_decimal(l[:non_dutiable_amt])

      other_fees = BigDecimal.new("0")

      Array.wrap(l[:fees]).each do |fee|
        case fee[:customs_fee_code].to_i
        when 499
          line.mpf = parse_decimal fee[:amt_fee]
          line.prorated_mpf = parse_decimal fee[:amt_fee_prorated]

          # If the mpf amount is below the amount required for proration, the
          # value may be zero. Since we tell everyone to always use the proration field
          # in reporting, make sure to use always fill in the prorated amount.
          if line.prorated_mpf.nil? || line.prorated_mpf == 0
            line.prorated_mpf = line.mpf
          end
        when 501
          line.hmf = parse_decimal fee[:amt_fee]
        when 56
          line.cotton_fee = parse_decimal fee[:amt_fee]
        else
          if fee[:amt_fee_prorated].to_f > 0
            other_fees += parse_decimal fee[:amt_fee_prorated]
          else
            other_fees += parse_decimal fee[:amt_fee]
          end
        end
      end

      line.other_fees = other_fees if other_fees.nonzero?

      Array.wrap(l[:penalties]).each do |p|
        case p[:penalty_type].to_s.upcase
        when 'ADA'
          line.add_case_number = p[:case_no]
          line.add_bond = p[:bonded].to_s.upcase == "Y"
          line.add_duty_amount = parse_decimal p[:duty_amt]
          line.add_case_value = parse_decimal p[:case_value]
          line.add_case_percent = parse_decimal p[:duty_percent]
        when 'CVD'
          line.cvd_case_number = p[:case_no]
          line.cvd_bond = p[:bonded].to_s.upcase == "Y"
          line.cvd_duty_amount = parse_decimal p[:duty_amt]
          line.cvd_case_value = parse_decimal p[:case_value]
          line.cvd_case_percent = parse_decimal p[:duty_percent]
        end
      end

      # Prefer the container sub-element to the actual container_no on the line level.
      # There's actually two ways to key containers on the invoice line.  The sub-element way
      # is accessed through a dropdown list in KEC so it should be more accurate than
      # the one on the line, which is just keyed into a textbox.
      Array.wrap(l[:containers]).each do |cont|
        container_number = cont[:container_no].to_s.strip
        next if container_number.blank?

        container = entry.containers.find {|c| c.container_number == container_number}
        line.container = container if container
      end

      if line.container.nil? && !l[:container_no].blank?
        container_number = l[:container_no].strip
        container = entry.containers.find {|c| c.container_number == container_number}
        line.container = container if container
      end
      nil
    end

    def set_invoice_tariff_data t, tariff
      tariff.hts_code = t[:tariff_no]
      tariff.duty_amount = parse_decimal(t[:duty_specific]) + parse_decimal(t[:duty_additional]) + parse_decimal(t[:duty_advalorem]) + parse_decimal(t[:duty_other])
      tariff.entered_value = parse_decimal t[:value_entered]
      tariff.duty_rate = tariff.entered_value > 0 ? tariff.duty_amount / tariff.entered_value : 0
      tariff.spi_primary = t[:spi_primary]
      tariff.spi_secondary = t[:spi_secondary]
      tariff.classification_qty_1 = parse_decimal t[:qty_1]
      tariff.classification_uom_1 = t[:uom_1]
      tariff.classification_qty_2 = parse_decimal t[:qty_2]
      tariff.classification_uom_2 = t[:uom_2]
      tariff.classification_qty_3 = parse_decimal t[:qty_3]
      tariff.classification_uom_3 = t[:uom_3]
      tariff.gross_weight = t[:weight_gross]
      tariff.quota_category = t[:category_no]
      tariff.tariff_description = t[:tariff_desc]
      tariff.tariff_description = t[:tariff_desc_additional] unless t[:tariff_desc_additional].blank?
    end

    def set_lacey_data l, lacey
      lacey.line_number = l[:pg_seq_nbr]
      lacey.detailed_description = l[:detailed_description]
      lacey.value = parse_decimal l[:line_value]
      lacey.name = l[:component_name]
      lacey.quantity = parse_decimal l[:component_qty]
      lacey.unit_of_measure = l[:component_uom]
      lacey.genus = l[:scientific_genus_name]
      lacey.species = l[:scientific_species_name]
      lacey.harvested_from_country = l[:country_harvested]
      # Store these as fractional amounts, NOT whole value percentages -> .10 and not 10 for 10%.
      lacey.percent_recycled_material = parse_decimal l[:percent_recycled_material], decimal_offset: 6
      lacey.container_numbers = l[:containers].join("\n ") unless l[:containers].blank?
    end

    def process_containers e, entry
      entry.containers.destroy_all

      Array.wrap(e[:containers]).each do |c|
        container = entry.containers.build
        set_container_data c, container
      end
      
      nil
    end

    def set_container_data c, container
      container.container_number = c[:number]
      container.goods_description = [c[:desc_content_1], c[:desc_content_2]].delete_if {|d| d.blank?}.join "\n "
      container.container_size = c[:size]
      container.weight = c[:weight]
      container.quantity = c[:quantity]
      container.uom = c[:uom]
      container.seal_number = c[:seal_no]
      container.fcl_lcl = c[:lcl_fcl]
      container.size_description = c[:type_desc]
      container.teus = c[:teu]
    end

    def process_broker_invoices e, entry
      # Don't destroy the invoices where the incoming data has the same fingerprint as the existing
      # invoice, we want to retain any sync records that might be associated with existing invoices
      fingerprint_user = User.integration
      fingerprints = {}
      entry.broker_invoices.each do |bi|
        fingerprints[bi.invoice_number] = fingerprint_invoice(bi, fingerprint_user)
      end

      invoices_saved = Set.new

      Array.wrap(e[:broker_invoices]).each do |bi|
        invoice_number = bi[:file_no].to_s + bi[:suffix].to_s

        # Migrate any existing invoice's sync records to the new invoice record we're creating
        existing_invoice = entry.broker_invoices.find {|inv| inv.invoice_number == invoice_number } 

        if existing_invoice
          invoice = BrokerInvoice.new entry: entry
        else
          invoice = entry.broker_invoices.build
        end

        set_broker_invoice_header_data bi, invoice

        Array.wrap(bi[:lines]).each do |bl|
          line = invoice.broker_invoice_lines.build
          set_broker_invoice_line_data bl, line
        end

        if existing_invoice
          existing_invoice.sync_records.each do |existing_sync|
            sr = invoice.sync_records.build 
            existing_sync.copy_attributes_to sr
          end
          # Delete the existing invoice and then add the new invoice to the entry
          # We have to destroy and not just mark as destroyed, otherwise the validation
          # later that ensures the same invoice number is used will trip
          existing_invoice.destroy
          # Add to the entry WITHOUT triggering a database insert (the save at the end on the entry
          # should trigger the database insert).
          # This is literally the least hacky way I could see to add an object onto a relation that
          # doesn't do a insert right away (stupid rails)
          entry.association(:broker_invoices).add_to_target(invoice)
        end

        invoices_saved << invoice_number
      end

      # Now delete all invoices that were already persisted but not referenced in the invoices_saved
      entry.broker_invoices.each do |inv|
        next if inv.marked_for_destruction? || invoices_saved.include?(inv.invoice_number) || !inv.persisted?

        inv.mark_for_destruction
      end
      nil
    end

    def fingerprint_invoice broker_invoice, user
      fingerprint_setup = {
        model_fields: [:bi_invoice_number, :bi_customer_number, :bi_invoice_date, :bi_invoice_total],
        broker_invoice_lines: {
          model_fields: [:bi_line_charge_code, :bi_line_charge_description, :bi_line_charge_amount, :bi_line_vendor_name, :bi_line_vendor_reference, :bi_line_charge_type]
        }

      }

      broker_invoice.generate_fingerprint fingerprint_setup, user
    end

    def set_broker_invoice_header_data bi, invoice
      invoice.invoice_number = bi[:file_no].to_s + bi[:suffix].to_s
      invoice.source_system = Entry::KEWILL_SOURCE_SYSTEM
      invoice.broker_reference = bi[:file_no]
      invoice.suffix = bi[:suffix]
      invoice.invoice_date = parse_numeric_date bi[:invoice_date]
      invoice.invoice_total = parse_decimal bi[:total_amount]
      invoice.customer_number = bi[:bill_to_cust]
      invoice.bill_to_name = bi[:name]
      invoice.bill_to_address_1 = bi[:address_1]
      invoice.bill_to_address_2 = bi[:address_2]
      invoice.bill_to_city = bi[:city]
      invoice.bill_to_state = bi[:state]
      invoice.bill_to_zip = bi[:zip]
      invoice.bill_to_country = Country.find_by_iso_code(bi[:country]) unless bi[:country].blank?
    end

    def set_broker_invoice_line_data il, line
      line.charge_code = il[:charge].to_s.rjust(4, '0')
      line.charge_description = il[:description].presence || "NO DESCRIPTION"
      line.charge_amount = parse_decimal il[:amount]
      line.vendor_name = il[:vendor_name]
      line.vendor_reference = il[:vendor_ref]
      line.charge_type = il[:charge_type]
    end

    def earliest_date d1, d2
      if d1 && d2
        return ((d1 <=> d2) <= 0) ? d1 : d2
      else
        return d1 ? d1 : d2
      end
    end

    def latest_date d1, d2
      if d1 && d2
        return ((d1 <=> d2) < 0) ? d2 : d1
      else
        return d1 ? d1 : d2
      end
    end

    def get_importer customer_number, customer_name
      importer = nil
      if customer_number
        Lock.acquire("CreateAllianceCustomer") do 
          importer = Company.where(alliance_customer_number: customer_number).first_or_create!(name: customer_name, importer: true)
        end
      end

      importer
    end

    def parse_decimal str, decimal_places: 2, decimal_offset: 2, rounding_mode: BigDecimal::ROUND_HALF_UP, no_offset: false
      return BigDecimal.new("0") if str.blank? || str == 0

      # Strip anything that's not a number or decimal point...some numeric fields are technical string fields in alliance
      # (.ie contract amount) and all sorts of garbage is added to them sometimes.
      str = str.to_s.gsub(/[^-\d\.]/, "")

      # if no_offset is passed, we're going to treat the incoming value like a standard numeric string, not the 
      # missing decimal garbage that Alliance normally sends.
      unless no_offset
        str = str.rjust(decimal_offset, '0')

        # The decimal places is what the value will be rounding to when returned
        # The decimal offset is used because all of the numeric values in Alliance are
        # stored and sent without decimal places "12345" instead of "123.45" so that 
        # they don't have to worry about decimal rounding and integer arithmetic can be done on everything.
        # This also means that we need to know the scale of the number before parsing it.
        unless str.include?(".") || decimal_offset <= 0
          begin
            str = str.insert(-(decimal_offset+1), '.')
          rescue IndexError
            str = "0"
          end
        end
      end

      BigDecimal.new(str).round(decimal_places, rounding_mode)
    end

    # make port code nil if all zeros
    def port_code v
      v = v.to_s.rjust(4, '0')
      v.blank? || v.match(/^[0]*$/) ? nil : v
    end

    def self.parse_numeric_datetime d
      # Every numeric date value that comes across is going to be Eastern Time
      d = d.to_i
      if d > 0
        time = d.to_s
        begin
          tz.parse time
        rescue 
          # For some reason Alliance will send us dates with a 60 in the minutes columns (rather than adding an hour)
          # .ie  201305152260
          if time =~ /60$/
            time = tz.parse(time[0..-3] + "00")
            time + 1.hour
          end
        end
      else
        nil
      end
    end

    def parse_numeric_datetime d
      self.class.parse_numeric_datetime d
    end

    def parse_numeric_date d
      d = d.to_i
      if d > 0
        time = d.to_i.to_s
        date = Date.strptime(time, "%Y%m%d") rescue nil

        # Stupid alliance sometimes sends dates with a time component of 24
        # If that happens, roll the date forward a day
        if date && time[8,2] == "24"
          date = date + 1.day
        end
        date
      else
        nil
      end
    end

    def self.tz
      ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
    end

    def tz
      self.class.tz
    end

    # We need to have all the invoice information already set in the entry at this point
    def process_fda_dates entry_json, entry
      fda_statuses = parse_fda_notes entry_json

      entry.commercial_invoices.each do |inv|
        inv.commercial_invoice_lines.each do |line|
          fda_line_dates = fda_statuses[line.customs_line_number.to_i]
          if fda_line_dates
            line.fda_review_date = fda_line_dates[:review]
            line.fda_hold_date = fda_line_dates[:hold]
            line.fda_release_date = fda_line_dates[:release]
          end
        end
      end
    end

    # The inputs should be the notes from the json, not the active record objects
    # The return from this is a hash w/ a key of the Customs Line Number => {:review_date, :hold_date, :release_date}
    def parse_fda_notes entry_json
      fda_line_numbers = Set.new
      Array.wrap(entry_json[:commercial_invoices]).each do |inv|
        Array.wrap(inv[:lines]).each do |line|
          line_no = line[:uscs_line_no]

          Array.wrap(line[:tariffs]).each do |t|
            if t[:fda] == "Y"
              fda_line_numbers << line_no
              break
            end
          end
        end
      end

      fda_statuses = {}
      fda_line_numbers.map {|line| {line => {review: nil, hold: nil, release: nil}}}.each {|hash| key = hash.keys.first; fda_statuses[key] = hash[key]}

      Array.wrap(entry_json[:notes]).each do |n|
        next unless n[:modified_by].try(:upcase) == "CUSTOMS"

        # FDA notes have 3 distinct variants:
        # 1) A "header" level note indicating the status of the file.  In general, this is followed by a line level
        #    message providing a more fine-grained detail about the individual line's status.  FDA Review does not provide
        #    individual line level details...once a review is received, all lines are considered under review.
        #
        #    Examples: "07/23/15 13:44 AG FDA 01 FDA REVIEW", "07/20/15 09:13 AG FDA 02 FDA HOLD", "07/17/15 17:07 AG FDA 05 FDA RELEASE"
        #
        # 2) A "line" level note indicating which particular 7501 customs line number status has been updated.  These lines indicate
        #    a single line or a range of lines that have status updates.  In general they follow and pertain to a header level
        #    note preceeding the line level, but sometimes line level notes are "floating" unrelated to any header - releases 
        #    a sometimes mixed in without any header messages.
        #
        #    Examples: "FDA MAY PROCEED USCS Ln 001 THRU 002", "FDA EXAM, NOTIFY USCS Ln 003  000", "FDA RELEASED USCS Ln 001 THRU 003"
        #
        # 3) An 'fda' level note indicating which FDA line's status has change.  We don't care about these, we only track at the 
        #    7501 level.
        # 
        #    Example: "Start Tar Pos 1 End Tar Pos 1 OGA Ln 001 THRU 001"

        # Scan for a header level note...the only one we care about is FDA Review, as that's the only one that doesn't
        # have follow up line level notes.
        result = n[:note].scan /(\d{2}\/\d{2}\/\d{2} \d{1,2}:\d{2})\s+AG\s+FDA\s+(\d{1,2})\s+(.*)\s+/i
        if result.length > 0 && result[0][1].to_i == 1
          status = result[0][1].to_i
          set_fda_dates fda_statuses, fda_line_numbers, :review, n[:date_updated]
        else 
          # Look for the FDA line specific statuses here..
          # This looks for a status message that has a leading status message, followed by "USCS Ln"
          # then some digits (the starting line number), then an optional THRU followed by another line number.

          # We'll need to match on the actual message to determine if we need to set the hold or release date...
          # Here's the full list of statuses along w/ their status numbers (not found in the Notes, unfortunately).
          # 
          # 01        FDA EXAM                                                        
          # 02        FDA EXAM, NOTIFY                                                
          # 05        FDA EXAM, DO NOT DEVAN                                          
          # 06        FDA EXAM, REDELIVER                                             
          # 07        FDA MAY PROCEED                                                 
          # 08        FDA RELEASED                                                    
          # 09        FDA RELEASED W/COMMENT                                          
          # 10        FDA DETAINED                                                    
          # 11        FDA CANCEL DETENTION                                            
          # 12        FDA REFUSED                                                     
          # 13        FDA PARTIAL RELEASE/REFUSE                                      
          # 14        FDA CANCEL REFUSAL
          # 14        FDA DOCUMENTS REQUIRED

          # FDA MAY PROCEED, FDA RELEASED, FDA RELEASED W/COMMENT are considered release date notifications
          # All others are considered hold dates

          result = n[:note].scan /(.*) USCS Ln (\d+)\s*(?:THRU\s+(\d+))?/i
          if result.length > 0
            # We really don't need to care about the actual line level status message since we're only tracking
            # if the line is review/hold/released.
            # All we care about here is the line numbers involved.
            message = result[0][0]
            lines_start = result[0][1].to_i
            lines_end = result[0][2].to_i

            if lines_start > 0
              lines_end = lines_start if lines_end < lines_start

              date_field = nil
              case result[0][0]
              when /\s*(?:(?:FDA MAY PROCEED)|(?:FDA RELEASED))/i
                date_field = :release
              else
                date_field = :hold
              end

              if date_field
                set_fda_dates fda_statuses, (lines_start .. lines_end).to_a, date_field, n[:date_updated]
              end
            end
          end
        end
      end

      fda_statuses
    end

    def set_fda_dates statuses, line_numbers, date_key, date
      date = parse_numeric_datetime date
      line_numbers.each do |num|
        # Just because we get an FDA status about a customs line, doesn't mean that it's actually an FDA line.
        # Sometimes we get a message like Ln 002 THRU 010 and lines 7 and 8 aren't FDA lines.  We don't want to
        # record fda dates against those lines.
        statuses[num][date_key] = date if statuses[num]
      end
    end

    def pending_fda_release_line_count entry
      count = 0
      entry.commercial_invoices.each do |inv|
        inv.commercial_invoice_lines.each do |invoice_line|
          # If either review or hold date is set and there is no release date, then we're considering the line pending release
          count += 1 if (invoice_line.fda_review_date || invoice_line.fda_hold_date) && invoice_line.fda_release_date.nil?
        end
      end

      count
    end

end; end; end;