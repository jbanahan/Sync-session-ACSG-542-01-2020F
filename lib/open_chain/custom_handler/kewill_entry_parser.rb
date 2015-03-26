require 'open_chain/sql_proxy_client'

module OpenChain; module CustomHandler; class KewillEntryParser

  def self.parse json_content, opts={}
    entry = json_content.is_a?(String) ? ActiveSupport::JSON.decode(json_content) : json_content
    self.new.process_entry entry, opts
  end

  def self.parse_json json_content, opts={}
    # This is the method that's called by the controller, we'll want to save off the json data it sends
    # first before parsing it, so the data that was exported is archived.

    # TODO Add some saving of the json content to S3 prior to processing the file
    parse json_content, opts
  end

  def process_entry json, opts={}
    #Unwrap the data from the outer entity wrapper
    json = json['entry']

    raise "Expected to find 'entry' entity inside JSON.  Nothing was found." if json.nil?

    entry = find_and_process_entry(json.with_indifferent_access) do |e, entry|
      process_entry_header e, entry
      process_dates e, entry
      process_notes e, entry

      entry.save!
      entry
    end

    OpenChain::AllianceImagingClient.request_images(entry.broker_reference) if entry

    # At this point, we're not processing enough information via this method for us to bother doing event notifications.
    # Once we parse all commercial and broker invoices, we probably should do notifies.
    entry
  end

  private 
    def find_and_process_entry(e)
      entry = nil 
      file_no = e['file_no'].to_s
      updated_at = parse_numeric_datetime(e['updated_at'])

      Lock.acquire(Lock::ALLIANCE_PARSER, times: 3) do
        entry = Entry.where(broker_reference: file_no, source_system: OpenChain::AllianceParser::SOURCE_CODE).first_or_create! expected_update_time: updated_at

        if skip_file? entry, updated_at
          entry = nil
        end
      end

      # entry will be nil if we're skipping the file due to it being outdated
      if entry 
        Lock.with_lock_retry(entry) do
          # The lock call here can potentially update us with new data, so we need to check again that another process isn't processing a newer file
          entry.expected_update_time = updated_at
          return yield e, entry unless skip_file?(entry, updated_at)
        end
      end
    end

    def parse_numeric_datetime d
      # Every numeric date value that comes across is going to be Eastern Time
      d = d.to_i
      if d > 0
        time = d.to_i.to_s
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

    def skip_file? entry, expected_update_time
      # Skip if the expected update time on the entry is newer than the one from the json data
      # ALSO skip if the last exported from source value is newer than the file.
      # For now, the alliance flat file data is exactly the same data as the data from here (probably better)
      # so don't ovewrite it with this data for the moment.
      if entry
        ex = entry.expected_update_time
        last_export = entry.last_exported_from_source

        (ex && ex > expected_update_time) || (last_export && last_export > expected_update_time)
      else
        false
      end
    end

    def process_entry_header e, entry
      entry.customer_number = e[:cust_no]
      entry.entry_number = e[:entry_no]
      entry.release_cert_message = e[:cr_certification_output_mess]
      entry.fda_message = e[:fda_output_mess]
    end

    def process_notes e, entry
      notes = Array.wrap(e[:notes])

      notes.each do |n|
        note = n[:note]
        generated_at = parse_numeric_datetime(n[:date_updated])

        #comment = entry.entry_comments.build body: n[:note], username: n[:modified_by], generated_at: parse_numeric_date(n[:date_updated])
        # The public private flag is set a little wonky because we do a before_save callback as a further step to determine if the 
        # comment should be public or not.  This is skipped if the flag is already set.
        #if n[:confidential].to_s == "Y"
        #  comment.public_comment = false
        #end

        if note.to_s.downcase.include?("document image created for f7501f") || note.to_s.downcase.include?("document image created for form_n7501")
          entry.first_7501_print = earliest_date(entry.first_7501_print, generated_at)
          entry.last_7501_print = latest_date(entry.first_7501_print, generated_at)
        end
      end
    end

    def process_dates e, entry
      dates = Array.wrap(e[:dates])

      dates.each do |date_field|
        case date_field[:date_no].to_i
        when 1
          entry.export_date = parse_numeric_date(date_field[:date])
        when 3, 98
          #both 3 and 98 are docs received for different customers
          entry.docs_received_date = parse_numeric_date(date_field[:date])
        when 4
          entry.file_logged_date = parse_numeric_datetime(date_field[:date])
        when 9
          entry.first_it_date = earliest_date(entry.first_it_date, parse_numeric_date(date_field[:date]))
        when 11
          entry.eta_date = parse_numeric_date(date_field[:date])
        when 12
          entry.arrival_date = parse_numeric_datetime(date_field[:date])
        when 16
          entry.entry_filed_date = parse_numeric_datetime(date_field[:date])
        when 19
          entry.release_date = parse_numeric_datetime(date_field[:date])
        when 20
          entry.fda_release_date = parse_numeric_datetime(date_field[:date])
        when 24
          entry.trucker_called_date = parse_numeric_datetime(date_field[:date])
        when 25
          entry.delivery_order_pickup_date = parse_numeric_datetime(date_field[:date])
        when 26
          entry.freight_pickup_date = parse_numeric_datetime(date_field[:date])
        when 28
          entry.last_billed_date = parse_numeric_datetime(date_field[:date])
        when 32
          entry.invoice_paid_date = parse_numeric_datetime(date_field[:date])
        when 42
          entry.duty_due_date = parse_numeric_date(date_field[:date])
        when 48
          entry.daily_statement_due_date = parse_numeric_date(date_field[:date])
        when 52
          entry.free_date = parse_numeric_datetime(date_field[:date])
        when 85
          entry.edi_received_date = parse_numeric_date(date_field[:date])
        when 108
          entry.fda_transmit_date = parse_numeric_datetime(date_field[:date])
        when 121
          entry.daily_statement_approved_date = parse_numeric_date(date_field[:date])
        when 2014
          entry.final_delivery_date = parse_numeric_datetime(date_field[:date])
        when 99202
          entry.first_release_date = parse_numeric_datetime(date_field[:date])
        when 92007
          entry.isf_sent_date = parse_numeric_datetime(date_field[:date])
        when 92008
          entry.isf_accepted_date = parse_numeric_datetime(date_field[:date])
        when 93002
          entry.fda_review_date = parse_numeric_datetime(date_field[:date])
        when 99212
          entry.first_entry_sent_date = parse_numeric_datetime(date_field[:date])
        when 99310
          entry.monthly_statement_received_date = parse_numeric_date(date_field[:date])
        when 99311
          entry.monthly_statement_paid_date = parse_numeric_date(date_field[:date])
        end
      end
    end

    def process_bill_numbers e, entry
      it_numbers = Set.new
      master_bills = Set.new
      house_bills = Set.new
      subhouse_bills = Set.new

      Array.wrap(e[:ids]).each do |id|
        it_numbers << id[:it_no]
        master_bills << id[:scac].to_s + id[:master_bill].to_s
        house_bills << id[:house_bill].to_s
        subhouse_bills << id[:sub_bill].to_s
      end
      blank = lambda {|d| d.blank?}
      entry.it_numbers = it_numbers.reject &blank
      entry.master_bills_of_lading = master_bills.reject &blank
      entry.house_bills_of_lading = house_bills.reject &blank
      entry.sub_house_bills_of_lading = subhouse_bills.reject &blank
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
end; end; end;