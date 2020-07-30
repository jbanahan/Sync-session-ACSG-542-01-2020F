require 'open_chain/s3'
require 'open_chain/integration_client_parser'
require 'open_chain/alliance_imaging_client'
require 'open_chain/fiscal_month_assigner'
require 'open_chain/custom_handler/entry_parser_support'

module OpenChain; module CustomHandler; class KewillEntryParser
  include OpenChain::IntegrationClientParser
  include OpenChain::CustomHandler::EntryParserSupport

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
    7 => {attribute: :import_date, datatype: :date},
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
    48 => {attribute: :daily_statement_due_date, datatype: :date},
    52 => :free_date,
    85 => {attribute: :edi_received_date, datatype: :date},
    108 => :fda_transmit_date,
    121 => {attribute: :daily_statement_approved_date, datatype: :date},
    906 => :summary_accepted_date,
    2014 => :final_delivery_date,
    2222 => :worksheet_date,
    2223 => :available_date,
    3000 => {attribute: :miscellaneous_entry_exception_date},
    3001 => {attribute: :invoice_missing_date},
    3002 => {attribute: :bol_discrepancy_date},
    3003 => {attribute: :detained_at_port_of_discharge_date},
    3004 => {attribute: :invoice_discrepancy_date},
    3005 => {attribute: :docs_missing_date},
    3006 => {attribute: :hts_missing_date},
    3007 => {attribute: :hts_expired_date},
    3008 => {attribute: :hts_misclassified_date},
    3009 => {attribute: :hts_need_additional_info_date},
    3010 => {attribute: :mid_discrepancy_date},
    3011 => {attribute: :additional_duty_confirmation_date},
    3012 => {attribute: :pga_docs_missing_date},
    3013 => {attribute: :pga_docs_incomplete_date},
    5023 => :cancelled_date,
    92007 => :isf_sent_date,
    92008 => :isf_accepted_date,
    92033 => :first_release_received_date,
    93002 => :fda_review_date,
    99202 => :first_release_date,
    99212 => :first_entry_sent_date,
    99310 => {attribute: :monthly_statement_received_date, datatype: :date},
    99311 => {attribute: :monthly_statement_paid_date, datatype: :date},
    99628 => {attribute: :ams_hold_date, directive: :hold},
    99663 => {attribute: :ams_hold_date, directive: :hold},
    99629 => {attribute: :ams_hold_date, directive: :hold},
    99670 => {attribute: :ams_hold_date, directive: :hold},
    99630 => {attribute: :ams_hold_release_date, directive: :hold_release},
    99616 => {attribute: :aphis_hold_date, directive: :hold},
    99662 => {attribute: :aphis_hold_date, directive: :hold},
    99617 => {attribute: :aphis_hold_date, directive: :hold},
    99669 => {attribute: :aphis_hold_date, directive: :hold},
    99618 => {attribute: :aphis_hold_release_date, directive: :hold_release},
    99694 => {attribute: :atf_hold_date, directive: :hold},
    99701 => {attribute: :atf_hold_date, directive: :hold},
    99695 => {attribute: :atf_hold_date, directive: :hold},
    99700 => {attribute: :atf_hold_date, directive: :hold},
    99696 => {attribute: :atf_hold_release_date, directive: :hold_release},
    90036 => {attribute: :cargo_manifest_hold_date, directive: :hold},
    90024 => {attribute: :cargo_manifest_hold_date, directive: :hold},
    90026 => {attribute: :cargo_manifest_hold_date, directive: :hold},
    90037 => {attribute: :cargo_manifest_hold_release_date, directive: :hold_release},
    90054 => [{attribute: :cbp_hold_date, directive: :hold}, {attribute: :cbp_intensive_hold_date, directive: :hold}],
    90051 => {attribute: :cbp_hold_date, directive: :hold},
    90050 => {attribute: :cbp_hold_date, directive: :hold},
    90049 => {attribute: :cbp_hold_date, directive: :hold},
    90053 => {attribute: :cbp_hold_date, directive: :hold},
    90057 => {attribute: :cbp_hold_date, directive: :hold},
    5051  => {attribute: :cbp_hold_date, directive: :hold},
    5003  => [{attribute: :cbp_hold_date, directive: :hold}, {attribute: :cbp_intensive_hold_date, directive: :hold}],
    5099  => {attribute: :cbp_hold_date, directive: :hold},
    5090  => {attribute: :cbp_hold_date, directive: :hold},
    90055 => [{attribute: :cbp_hold_release_date, directive: :hold_release}, {attribute: :cbp_intensive_hold_release_date, directive: :hold_release}],
    90056 => {attribute: :cbp_hold_release_date, directive: :hold_release},
    5054  => {attribute: :cbp_hold_release_date, directive: :hold_release},
    5098  => {attribute: :cbp_hold_release_date, directive: :hold_release},
    99638 => {attribute: :ddtc_hold_date, directive: :hold},
    99664 => {attribute: :ddtc_hold_date, directive: :hold},
    99639 => {attribute: :ddtc_hold_date, directive: :hold},
    99671 => {attribute: :ddtc_hold_date, directive: :hold},
    99640 => {attribute: :ddtc_hold_release_date, directive: :hold_release},
    99689 => {attribute: :fda_hold_date, directive: :hold},
    99681 => {attribute: :fda_hold_date, directive: :hold},
    99683 => {attribute: :fda_hold_date, directive: :hold},
    99682 => {attribute: :fda_hold_date, directive: :hold},
    99688 => {attribute: :fda_hold_date, directive: :hold},
    99684 => {attribute: :fda_hold_release_date, directive: :hold_release},
    99604 => {attribute: :fsis_hold_date, directive: :hold},
    99605 => {attribute: :fsis_hold_date, directive: :hold},
    99660 => {attribute: :fsis_hold_date, directive: :hold},
    99667 => {attribute: :fsis_hold_date, directive: :hold},
    99607 => {attribute: :fsis_hold_release_date, directive: :hold_release},
    99611 => {attribute: :nhtsa_hold_date, directive: :hold},
    99661 => {attribute: :nhtsa_hold_date, directive: :hold},
    99668 => {attribute: :nhtsa_hold_date, directive: :hold},
    99613 => {attribute: :nhtsa_hold_release_date, directive: :hold_release},
    99645 => {attribute: :nmfs_hold_date, directive: :hold},
    99646 => {attribute: :nmfs_hold_date, directive: :hold},
    99665 => {attribute: :nmfs_hold_date, directive: :hold},
    99679 => {attribute: :nmfs_hold_date, directive: :hold},
    99647 => {attribute: :nmfs_hold_date, directive: :hold},
    99672 => {attribute: :nmfs_hold_date, directive: :hold},
    99648 => {attribute: :nmfs_hold_release_date, directive: :hold_release},
    5052  => {attribute: :usda_hold_date, directive: :hold},
    5055  => {attribute: :usda_hold_release_date, directive: :hold_release},
    5053  => {attribute: :other_agency_hold_date, directive: :hold},
    5056  => {attribute: :other_agency_hold_release_date, directive: :hold_release},
    91065 => {attribute: :one_usg_date, directive: :hold_release},
    99844 => :fish_and_wildlife_transmitted_date,
    99851 => [:fish_and_wildlife_secure_facility_date, {attribute: :fish_and_wildlife_hold_date, directive: :hold}],
    99847 => {attribute: :fish_and_wildlife_hold_date, directive: :hold},
    99850 => {attribute: :fish_and_wildlife_hold_date, directive: :hold},
    99853 => {attribute: :fish_and_wildlife_hold_date, directive: :hold},
    99846 => {attribute: :fish_and_wildlife_hold_release_date, directive: :hold_release}
  }

  def self.integration_folder
    # This parser is actually used across multiple deployment instances (hm and www.vfitrack.net)
    # and we could conceivable use it for more as well, so make sure the integration folder we're storing
    # to is tied to the system code as well
    ["#{MasterSetup.get.system_code}/_kewill_entry", "/home/ubuntu/ftproot/chainroot/#{MasterSetup.get.system_code}/_kewill_entry"]
  end

  # Due to volume concerns, entries received by this class are not recorded in the inbound file table.
  def self.log_file? bucket, key
    false
  end

  def self.parse json_content, opts={}
    # This is the method that's called by the controller, we'll want to save off the json data it sends
    # first before parsing it, so the data that was exported is archived.
    # Unwrap the data from the outer entity wrapper
    outer = json_content.is_a?(String) ? ActiveSupport::JSON.decode(json_content) : json_content
    json = outer['entry']
    return nil if json.nil?

    entry = nil

    begin
      entry = self.new.process_entry json, opts
    rescue => e
      error_handler e, json
    end

    if entry
      if MasterSetup.get.custom_feature?("Kewill Imaging")
        # We're setting up a message delay of 10 minutes here because it seems this feed comes across sometimes faster than
        # Kewill Imaging can store off the files locally.  The imaging request gets over to our imaging clients prior to the
        # image existing in Kewill Imaging and thus we don't get any files back.  So, use :delay_seconds in order to hold back
        # for 10 minutes.
        # There's also a point in time early on in data entry where the entry data is coming over fairly often, so we don't
        # want to constantly be requesting images on every single update.
        OpenChain::AllianceImagingClient.request_images(entry.broker_reference, delay_seconds: 600) unless opts[:imaging] == false
      end
      entry.broadcast_event(:save)
    end

    entry
  end

  def process_entry json, opts={}
    start_time = Time.zone.now
    user = User.integration
    entry = find_and_process_entry(json.with_indifferent_access) do |e, entry|
      preprocess entry
      process_entry_header e, entry
      process_dates e, entry
      # Liquidation data depends on the presence of the liquidation date
      # So we parse it after we've parsed dates.
      process_liquidation e, entry
      process_notes e, entry
      process_bill_numbers e, entry
      # Process containers before commercial invoices since invoice lines can link to containers
      process_containers e, entry
      process_commercial_invoices e, entry
      process_post_summary_corrections e, entry
      process_broker_invoices e, entry
      process_fda_dates e, entry
      process_trucker_information e, entry
      process_exceptions e, entry

      if opts[:key] && opts[:bucket]
        entry.last_file_path = opts[:key]
        entry.last_file_bucket = opts[:bucket]
      end

      postprocess e, entry, user

      begin
        OpenChain::FiscalMonthAssigner.assign entry
      rescue FiscalDateError => e
        # If the fiscal date is missing, then log it so we know there's an issue...but we don't want that to actually bomb
        # the entry load.
        e.log_me
      end

      entry.save!
      entry.update_column :time_to_process, ((Time.now-start_time) * 1000)

      entry.create_snapshot user
      entry
    end

    entry
  end

  private

    def self.error_handler e, json
      # Re-raise a deadlock error, there's nothing wrong with the data, so the entry should
      # process next time through when the job queue reprocesses the file.
      raise e if OpenChain::DatabaseUtils.deadlock_error?(e) || !MasterSetup.get.production?

      # Add the entity wrapper name back in so the data can easily just be passed back through
      # the parser for testing/problem solving
      json_to_tempfile({"entry" => json}) do |f|
        e.log_me ["Kewill Entry Parser Failure"], [f.path]
      end

      nil
    end

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
      file_no, updated_at, extract_time, cancelled_date = self.class.entry_info e
      # For some reason there's some rare cases where an entry comes over with no file number...ignore them.
      return nil if file_no.blank? || file_no == "0"

      Lock.acquire("Entry-#{Entry::KEWILL_SOURCE_SYSTEM}-#{file_no}") do
        # Make sure the entry has not been purged. We want to allow for re-using file numbers, so we'll assume that any data exported from the source system AFTER the purge record was created
        # means that the data is for a totally new entry and not for the one that was purged
        break if Entry.purged? Entry::KEWILL_SOURCE_SYSTEM, file_no, extract_time

        # If the entry has been cancelled, we don't want to go creating it...it's pointless
        entry_relation = Entry.where(broker_reference: file_no, source_system: Entry::KEWILL_SOURCE_SYSTEM)
        if !cancelled_date.nil?
          entry = entry_relation.first
        else
          entry = entry_relation.first_or_create! expected_update_time: updated_at, last_exported_from_source: extract_time
        end

        if skip_file? entry, extract_time
          entry = nil
        end
      end

      # entry will be nil if we're skipping the file due to it being outdated
      if entry
        Lock.with_lock_retry(entry) do
          # The lock call here can potentially update us with new data, so we need to check again that another process isn't processing a newer file
          if !skip_file?(entry, extract_time)

            # If the file has been cancelled, it should be purged immediately...don't update any data, just purge it (with extreme vengeance)
            if cancelled_date
              process_cancelled_entry entry, extract_time
              return nil
            else
              entry.expected_update_time = updated_at
              entry.last_exported_from_source = extract_time
              return yield e, entry
            end
          end
        end
      end
    end

    def process_cancelled_entry entry, extract_time
      # Use the extract time of the purge, so that we're consistent in how we're tracking automated purges by
      # always using a value that's tracking against the source system's clock (.ie Kewill's database)
      entry.purge! date_purged: extract_time
    end

    def skip_file? entry, last_exported_from_source
       # Skip if the last exported from source value is newer than the file's value
      entry && entry.last_exported_from_source && entry.last_exported_from_source > last_exported_from_source
    end

    def self.entry_info e
      [e['file_no'].to_s, parse_numeric_datetime(e['updated_at']), tz.parse(e['extract_time']), cancelled_date(e)]
    end

    def self.cancelled_date entry_json
      Array.wrap(entry_json[:dates]).each do |date|
        next unless date[:date_no].to_i == 5023

        return parse_numeric_datetime(date[:date])
      end

      nil
    end

    def self.s3_file_path e
      # File No and Extract Time should never, ever be missing
      file_no, updated_at, extract_time, cancelled_date = entry_info e

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
      DATE_MAP.each_key do |v|
        configs = get_date_config v
        next if configs.empty?
        # Don't clear anything w/ a first/last/ifnull directive, since we want to retain those original dates
        configs.each do |c|
          next unless c[:directive] == :none
          attributes[c[:attribute]] = nil
        end
      end
      entry.assign_attributes attributes.merge({hold_date: nil, hold_release_date: nil})
      nil
    end

    # Any sort of post-handling of the data that needs to be done prior to saving belongs in this method
    def postprocess e, entry, user
      entry.monthly_statement_due_date = find_statement_due_date(e, entry)

      process_totals e, entry

      postprocess_notes entry

      postprocess_statements entry, user

      process_special_tariffs entry
      nil
    end

    def postprocess_notes entry
      entry.summary_rejected = summary_rejected?(entry)
    end

    def summary_rejected? entry
      # What we're looking for here is to determine if there is an entry comment (note) indicating that the summary
      # has been been rejected and not yet replaced or added.
      rejected = false
      entry.entry_comments.each do |note|
        next unless note.username.to_s.upcase == "CUSTOMS"

        body = note.body.to_s.upcase
        if body.include? "TRANSACTION DATA REJECTED"
          rejected = true
        elsif body.include?("SUMMARY HAS BEEN ADDED") || body.include?("SUMMARY HAS BEEN REPLACED") || body.include?("ACH PAYMENT ACCEPTED")
          rejected = false
        end
      end

      rejected
    end

    def find_statement_due_date e, entry
      due_date = nil

       # I'm not entirely sure why you'd have a periodic statement due date, where you don't have a statement number
      # but the old feed did this too, so I'm keeping it in place
      pms_year = e[:pms_year]
      pms_month = e[:pms_month]
      pms_date = nil
      if pms_year.try(:nonzero?) && pms_month.try(:nonzero?)
        pms_calendar_event = Calendar.find_all_events_in_calendar_month(pms_year, pms_month, "PMS").first
        pms_date = pms_calendar_event&.event_date

        # We're only currently tracking pms days since 2012, if we don't have a date after that time..then error
        # so that we can set up the schedule

        # The entry filed date check is here because the ISF system creates shell entry records with Arrival Dates sometimes months
        # in advance - which is valid.  However, the presence of the arrival date also then triggers an attempt to determine a statement
        # date - which at this point in time is pointless as nothing has actually been filed for the entry yet and PMS statement dates may not
        # have even been published yet US CBP.  So wait till there's an entry filed date to bother reporting on the missing PMS values

        # FYI...the formula for creating PMS Date events is the PMS Due Date is the 15th business day of the month.  In other words, count
        # forward from 1st of the month every weekday that's not also a federal holiday.
        if pms_date.nil? && pms_year > 2012 && !entry.entry_filed_date.nil?
          StandardError.new("File ##{entry.broker_reference} / Division ##{entry.division_number}: No Periodic Monthly Statement Dates Calendar found for #{pms_year} and #{pms_month}.  This data must be set up immediately.").log_me
        end
      end

      pms_date
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
      entry.consignee_postal_code = e[:uc_zip]
      entry.consignee_country_code = e[:uc_country]
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
      entry.total_taxes = parse_decimal(e[:taxes_tot])
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
      entry.import_country = us
      entry.split_shipment = e[:split].to_s.upcase == "Y"
      entry.split_release_option = e[:split_release_option].to_i if e[:split_release_option].to_i > 0
      entry.bond_surety_number = e[:bond_surety_no]

      nil
    end

    def postprocess_statements entry, user
      if entry.daily_statement_number
        daily_statement_entry = DailyStatementEntry.joins(:daily_statement).where(broker_reference: entry.broker_reference).where(daily_statements: {statement_number: entry.daily_statement_number}).readonly(false).first
        # This could happen if the statement came over before the entry did (not entirely sure if that's really possible, but might as well program for it)
        if daily_statement_entry
          Lock.db_lock(daily_statement_entry) do
            daily_statement_entry.entry_id = entry.id

            # If we changed the amount billed on the statement (like if new broker invoices come over), we need to snapshot the invoice then
            daily_statement_entry.billed_amount = entry.broker_invoices.map {|bi| !bi.marked_for_destruction? ? bi.total_billed_duty_amount : 0 }.sum
            if daily_statement_entry.changed?
              daily_statement_entry.save!

              daily_statement_entry.daily_statement.create_snapshot user, nil, entry.last_file_path
            end
          end
        end
      end
    end

    def pad_numeric v, pad_length, pad_char
      if v.to_s =~ /^\d+(?:\.\d+)?$/
        v.to_s.rjust(pad_length, pad_char)
      else
        v
      end
    end

    def process_liquidation e, entry
      liquidation_date = Array.wrap(e[:dates]).find {|date_json| date_json['date_no'] == 44 }
      liquidation_date = parse_numeric_datetime(liquidation_date['date']) if liquidation_date.present?
      if pad_numeric(e[:type_liquidation].to_s, 2, '0').downcase == 'r'
        entry.reliquidation_date = liquidation_date
      else
        entry.liquidation_date = liquidation_date
      end

      test_date = entry.liquidation_date.presence || entry.reliquidation_date.presence
      if entry.liquidation_date && Time.zone.now.to_date >= test_date.in_time_zone(tz).to_date
        entry.liquidation_type_code = pad_numeric(e[:type_liquidation].to_s, 2, '0')
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
      accumulations = {}
      [
        :commercial_invoice_numbers, :total_packages_uom, :mids, :country_export_codes, :country_origin_code, :vendor_names, :total_units_uoms,
        :po_numbers, :part_numbers, :departments, :store_names, :product_lines, :spis, :charge_codes, :container_numbers,
        :container_sizes, :fcl_lcls, :customer_references
      ].each {|v| accumulations[v] = Set.new }

      totals = {}
      [
        :total_invoiced_value, :total_non_dutiable_amount, :total_units, :total_cvd, :total_add, :other_fees, :broker_invoice_total
      ].each {|v| totals[v] = BigDecimal("0")}

      max_line_number = 0

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
          max_line_number = il.customs_line_number if il.customs_line_number > max_line_number

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
          entry.customer_references = (refs - pos).join(multi_value_separator)
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
          if v.blank?
            entry.fcl_lcl = ""
          else
            entry.fcl_lcl = v.size > 1 ? "Mixed" : (v.first.upcase == "L" ? "LCL" : "FCL")
          end
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
          # Only set a zero value if the entry value has already been set and we're clearing it
          entry.total_cvd = value if value.nonzero? || entry.total_cvd.try(:nonzero?)
        when :total_add
          entry.total_add = value if value.nonzero? || entry.total_add.try(:nonzero?)
        when :total_non_dutiable_amount
          entry.total_non_dutiable_amount = value if value.nonzero? || entry.total_non_dutiable_amount.try(:nonzero?)
        when :other_fees
          entry.other_fees = value if value.nonzero? || entry.other_fees.try(:nonzero?)
        end
      end

      entry.summary_line_count = max_line_number

      entry.fda_pending_release_line_count = pending_fda_release_line_count entry
      nil
    end

    def accumulated hash, key
      hash[key].keep_if {|v| !v.blank? }.to_a.join multi_value_separator
    end

    def process_trucker_information e, entry
      # This is primarily here for tests. e["delivery_orders"] should always exist, though it may be empty.
      return if e["delivery_orders"].blank?

      trucker_names = Set.new
      deliver_to_names = Set.new

      e["delivery_orders"].each do |delivery_order|
        trucker_names << delivery_order["trucker_name"]
        deliver_to_names << delivery_order["deliver_to_name"]
      end

      entry.trucker_names = trucker_names.to_a.join("\n ")
      entry.deliver_to_names = deliver_to_names.to_a.join("\n ")
    end

    def process_exceptions e, entry
      # Delete any existing exceptions.
      entry.entry_exceptions.destroy_all

      Array.wrap(e[:exceptions]).each do |n|
        code = n[:exception_code]
        creation_date = (n[:created_date] ? tz.parse(n[:created_date]) : nil)
        resolved_date = (n[:resolved_date] ? tz.parse(n[:resolved_date]) : nil)

        case code
        when "CD"
          entry.customs_detention_exception_opened_date = creation_date
          entry.customs_detention_exception_resolved_date = resolved_date
        when "CI"
          entry.classification_inquiry_exception_opened_date = creation_date
          entry.classification_inquiry_exception_resolved_date = resolved_date
        when "CRH", "TGT"
          entry.customer_requested_hold_exception_opened_date = creation_date
          entry.customer_requested_hold_exception_resolved_date = resolved_date
        when "UCE"
          entry.customs_exam_exception_opened_date = creation_date
          entry.customs_exam_exception_resolved_date = resolved_date
        when "DD"
          entry.document_discrepancy_exception_opened_date = creation_date
          entry.document_discrepancy_exception_resolved_date = resolved_date
        when "FDA"
          entry.fda_issue_exception_opened_date = creation_date
          entry.fda_issue_exception_resolved_date = resolved_date
        when "FW"
          entry.fish_and_wildlife_exception_opened_date = creation_date
          entry.fish_and_wildlife_exception_resolved_date = resolved_date
        when "LAD"
          entry.lacey_act_exception_opened_date = creation_date
          entry.lacey_act_exception_resolved_date = resolved_date
        when "LD"
          entry.late_documents_exception_opened_date = creation_date
          entry.late_documents_exception_resolved_date = resolved_date
        when "MH"
          entry.manifest_hold_exception_opened_date = creation_date
          entry.manifest_hold_exception_resolved_date = resolved_date
        when "MD"
          entry.missing_document_exception_opened_date = creation_date
          entry.missing_document_exception_resolved_date = resolved_date
        when "PR"
          entry.pending_customs_review_exception_opened_date = creation_date
          entry.pending_customs_review_exception_resolved_date = resolved_date
        when "PI"
          entry.price_inquiry_exception_opened_date = creation_date
          entry.price_inquiry_exception_resolved_date = resolved_date
        when "USD"
          entry.usda_hold_exception_opened_date = creation_date
          entry.usda_hold_exception_resolved_date = resolved_date
        end

        entry.entry_exceptions.build(code: code, comments: n[:exception_comments],
                                     resolved_date: resolved_date, exception_creation_date: creation_date)
      end

      nil
    end

    def process_notes e, entry
      # There are sometimes thousands of comments...just do a delete here, rather than a destroy.  Entry comments don't have
      # descendents we need to worry about so the time savings can actually add up to multiple seconds here.
      # We're then going to use a specialized bulk import process to roll all the lines into a single SQL statement.
      # This is an attempt to workaround deadlocks occurring from doing hundreds of insert into statements
      # (which is triggered by database gap locks)

      # I don't know why but `entry.entry_comments.delete_all` is generating a distinct sql delete per comment, rather
      # than the single "delete from entry_comments where entry_id = ?"" that the documentation says it should be doing.
      # Possible rails bug?  Whatever it is, this is a workaround for that behavior not working.
      EntryComment.where(entry_id: entry.id).delete_all

      customs_response_times = []
      comments = []
      Array.wrap(e[:notes]).each do |n|
        note = n[:note]
        generated_at = parse_numeric_datetime(n[:date_updated])

        comment = EntryComment.new entry_id: entry.id, body: n[:note], username: n[:modified_by], generated_at: generated_at
        comments << comment
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

      if comments.length > 0
        EntryComment.import comments
      end

      entry.entry_filed_date = (customs_response_times.size > 0 ? customs_response_times.sort.first : nil)
      entry.entry_comments.reload

      nil
    end

    def get_date_config date_no
      config = Array.wrap DATE_MAP[date_no]
      out_config = []
      if config.present?
        config.each do |c|
          default_config = {datatype: :datetime, directive: :none}
          if c.is_a?(Symbol)
            out_config << default_config.merge({attribute: c})
          else
            out_config << default_config.merge(c)
          end
        end
      end

      out_config
    end

    def process_dates e, entry
      hrs = HoldReleaseSetter.new entry

      Array.wrap(e[:dates]).each do |date|
        configs = get_date_config date[:date_no].to_i
        next if configs.empty?

        configs.each do |c|
          in_val = (c[:datatype] == :date ? parse_numeric_date(date[:date]) : parse_numeric_datetime(date[:date]))

          val = nil
          case c[:directive]
          when :first
            val = earliest_date(in_val, entry.read_attribute(c[:attribute]))
          when :last
            val = latest_date(in_val, entry.read_attribute(c[:attribute]))
          when :ifnull
            # Only set the date field if the entry hasn't had the value already set
            next unless entry.read_attribute(c[:attribute]).blank?
            val = in_val
          when :hold
            hrs.set_any_hold_date in_val, c[:attribute]
          when :hold_release
            hrs.set_any_hold_release_date in_val, c[:attribute]
          else
            val = in_val
          end

          entry.assign_attributes(c[:attribute] => val) unless [:hold, :hold_release].member? c[:directive]
        end
      end

      hrs.set_summary_hold_date
      hrs.set_summary_hold_release_date
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
      entry.it_numbers = it_numbers.reject(&blank).sort.join(multi_value_separator)
      entry.master_bills_of_lading = master_bills.reject(&blank).sort.join(multi_value_separator)
      entry.house_bills_of_lading = house_bills.reject(&blank).sort.join(multi_value_separator)
      entry.sub_house_bills_of_lading = subhouse_bills.reject(&blank).sort.join(multi_value_separator)
      # Technically, based on the DB structure in Kewill, there can be more than 1 house carrier code
      # In practice, according to Mark, that won't happen.  So we're only pulling the first non-blank value encountered.
      entry.house_carrier_code = house_scacs.first
      nil
    end

    def process_commercial_invoices e, entry
      entry.destroy_commercial_invoices
      entry.entry_pga_summaries.destroy_all

      entry_effective_date = tariff_effective_date(entry)
      entry_pga_summary_data = Hash.new { |hash, key| hash[key] = {disclaimed_lines: 0, claimed_lines: 0} }

      Array.wrap(e[:commercial_invoices]).each do |i|
        invoice = entry.commercial_invoices.build
        set_invoice_header_data i, invoice
        Array.wrap(i[:lines]).each do |l|
          line = invoice.commercial_invoice_lines.build
          set_invoice_line_data l, line, entry

          Array.wrap(l[:tariffs]).each do |t|
            tariff = line.commercial_invoice_tariffs.build
            set_invoice_tariff_data t, tariff, line, invoice

            Array.wrap(t[:lacey]).each do |l|
              lacey = tariff.commercial_invoice_lacey_components.build
              set_lacey_data l, lacey
            end

            Array.wrap(t[:pga_summaries]).each do |p|
              pga_summary = tariff.pga_summaries.build
              set_pga_summary_data p, pga_summary
              entry_pga_summary_data[pga_summary.agency_code][pga_summary.disclaimed? ? :disclaimed_lines : :claimed_lines] += 1
            end
          end

          # When there are multiple tariff lines, only the first tariff line carries the entered value...therefore, we cannot calculate the
          # duty rate for each line solely off its entered value, since for tariff lines 2+ it will always be zero and therefore show a rate of zero,
          # even if there is duty listed.
          # We must sum the entered value from the tariff line and then calculate the duty rate for each line based off that sum'ed value.
          # Note that this also means that we have to delay this process until after all the line's tariffs are loaded.
          total_entered_value = line.total_entered_value
          line.commercial_invoice_tariffs.each do |t|
            calculate_duty_rates(t, line, entry_effective_date, total_entered_value)
          end
        end
      end

      # Build entry-level PGA summary info records.
      entry_pga_summary_data.each_key do |agency_code|
        disclaimed_count = entry_pga_summary_data[agency_code][:disclaimed_lines]
        claimed_count = entry_pga_summary_data[agency_code][:claimed_lines]
        entry.entry_pga_summaries.build(agency_code: agency_code, total_pga_lines: disclaimed_count + claimed_count,
                                        total_claimed_pga_lines: claimed_count, total_disclaimed_pga_lines: disclaimed_count)
      end

      nil
    end

    def set_invoice_header_data i, inv
      inv.invoice_number = i[:ci_no]
      inv.customer_reference = i[:cust_ref]
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

      inv.master_bills_of_lading = i[:master_bills].join(multi_value_separator) unless i[:master_bills].blank?
      inv.house_bills_of_lading = i[:house_bills].join(multi_value_separator) unless i[:house_bills].blank?
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
      line.freight_amount = parse_decimal l[:freight_amt]
      line.other_amount = parse_decimal l[:other_amt]
      line.cash_discount = parse_decimal l[:cash_discount]
      line.add_to_make_amount = parse_decimal l[:add_to_make_amt]
      line.computed_value = parse_decimal(l[:value_tot]) - parse_decimal(l[:non_dutiable_amt]) - parse_decimal(l[:add_to_make_amt])
      line.computed_adjustments = parse_decimal(l[:non_dutiable_amt]) + parse_decimal(l[:add_to_make_amt]) + parse_decimal(l[:other_amt]) +
                                     parse_decimal(l[:misc_discount]) + parse_decimal(l[:cash_discount]) + parse_decimal(l[:freight_amt])
      line.computed_net_value = parse_decimal(l[:value_tot]) - line.computed_adjustments
      line.first_sale = (l[:value_appraisal_method].to_s.upcase == "F" || parse_decimal(l[:contract]) > 0)
      line.value_appraisal_method = l[:value_appraisal_method]
      line.non_dutiable_amount = parse_decimal(l[:non_dutiable_amt])
      line.miscellaneous_discount = parse_decimal(l[:misc_discount])
      line.agriculture_license_number = l[:agriculture_license_no]
      line.ruling_number = l[:ruling_no]
      line.ruling_type = l[:ruling_type]

      other_fees = BigDecimal.new("0")

      Array.wrap(l[:fees]).each do |fee|
        case fee[:customs_fee_code].to_i
        # 499 is the MPF for standard entries, 311 is the MPF for informal entries
        # We should never receive both on a single entry.
        when 499, 311
          line.mpf = parse_decimal fee[:amt_fee]
          line.mpf_rate = parse_decimal fee[:alg_x_rate_advalorem], decimal_places: 8, decimal_offset: 8
          line.prorated_mpf = parse_decimal fee[:amt_fee_prorated]

          # If the mpf amount is below the amount required for proration, the
          # value may be zero. Since we tell everyone to always use the proration field
          # in reporting, make sure to use always fill in the prorated amount.
          if line.prorated_mpf.nil? || line.prorated_mpf == 0
            line.prorated_mpf = line.mpf
          end
        when 501
          line.hmf = parse_decimal fee[:amt_fee]
          line.hmf_rate = parse_decimal fee[:alg_x_rate_advalorem], decimal_places: 8, decimal_offset: 8
        when 56
          line.cotton_fee = parse_decimal fee[:amt_fee]
          line.cotton_fee_rate = parse_decimal fee[:alg_x_rate_specific], decimal_places: 8, decimal_offset: 8
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

    def set_invoice_tariff_data t, tariff, invoice_line, invoice_header
      tariff.hts_code = t[:tariff_no]
      # Duty Advalorem is any portion of the duty that's based on a percentage of the entered value.  Duty Rate looks like: 7%
      tariff.duty_advalorem = parse_decimal(t[:duty_advalorem])
      # Duty Specific are rates based on units of measure.  .ie 13.2¢/liter
      # There's plenty of times where you have both Advalorem and Specific Rates -> 13.2¢/liter + 7%
      tariff.duty_specific = parse_decimal(t[:duty_specific])
      # Duty Additional is where there's multiple specific rates, the second specific rate is put here.
      # 13.2¢/liter + 7% + 50.5¢/barrel (barrel amount would go in additional)
      tariff.duty_additional = parse_decimal(t[:duty_additional])
      # Not sure what this is supposed to be tracking, there's not a single tariff line in the entry system w/ a
      # duty other value...adding anyway, just in case.
      tariff.duty_other = parse_decimal(t[:duty_other])
      tariff.duty_amount = [tariff.duty_advalorem, tariff.duty_specific, tariff.duty_additional, tariff.duty_other].compact.sum
      tariff.entered_value = parse_decimal t[:value_entered]
      tariff.entered_value_7501 = tariff.entered_value.round
      # Add the computed rounded entered value to the invoice-level field.
      invoice_header.entered_value_7501 = invoice_header.entered_value_7501.to_i + tariff.entered_value_7501
      invoice_line.entered_value_7501 = invoice_line.entered_value_7501.to_i + tariff.entered_value_7501
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

    def process_post_summary_corrections e, entry
      Array.wrap(e[:post_summary_corrections]).each do |psc|
        Array.wrap(psc[:lines]).each do |psc_l|
          ci = entry.commercial_invoices.find { |ci| ci.invoice_number == psc_l[:ci_no] }
          cil = ci.commercial_invoice_lines.find { |cil| cil.line_number == psc_l[:ci_line_no] / 10 }
          cil.psc_date = parse_numeric_datetime psc[:sent_date]
          cil.psc_reason_code = psc_l[:reason_code]
        end
      end
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
      lacey.container_numbers = l[:containers].join(multi_value_separator) unless l[:containers].blank?
    end

    def set_pga_summary_data p, pga_summary
      pga_summary.sequence_number = p[:uscs_pg_seq_nbr]
      pga_summary.agency_code = p[:pg_agency_cd]
      pga_summary.program_code = p[:pg_program_cd]
      pga_summary.tariff_regulation_code = p[:pg_cd]
      pga_summary.commercial_description = p[:commercial_desc]
      pga_summary.agency_processing_code = p[:agency_processing_cd]
      pga_summary.disclaimer_type_code = p[:disclaimer_type_cd]
      pga_summary.disclaimed = p[:is_disclaimer].to_s.upcase == "Y"
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
      container.goods_description = [c[:desc_content_1], c[:desc_content_2]].delete_if {|d| d.blank?}.join multi_value_separator
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
      # Customer Number can be blank sometimes really early on in the shipment / entry process, just let that happen.  It just means until the entry is associated
      # with a customer that only internal users can view the entry.
      return nil if customer_number.blank?

      begin
        # There appears to be some situations where the customer_name can be blank even on long-established customers.  I think this is due to operations modifying something
        # on the entry incorrectly.  Regardless, as long as there's a customer_number for these and the importer account exists, then we should just use that account.
        # The ONLY time the customer name matters is when we're having to create the account.
        return Company.find_or_create_company!("Customs Management", customer_number, {alliance_customer_number: customer_number, importer: true, name: customer_name})
      rescue ActiveRecord::RecordInvalid => e
        # This is a case where we're trying to create the account, but the name came across blank...don't fail the entry on this, just create it without the importer
        return nil if customer_name.blank?

        # If we're failing for some other reason, then just re-raise the error.
        raise e
      end
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
        if date && time[8, 2] == "24"
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
