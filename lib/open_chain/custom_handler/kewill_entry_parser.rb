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
      entry.customer_number = e[:cust_no]
      entry.release_cert_message = e[:cr_certification_output_mess]
      entry.fda_message = e[:fda_output_mess]
      process_dates e, entry

      entry.save!
      entry
    end

    # At this point, we're not processing enough information via this method for us to bother doing event notifications.
    # Until we have commercial and broker invoices, we probably should do notifies.
    entry
  end

  private 
    def find_and_process_entry(e)
      entry = nil 
      file_no = e['file_no'].to_s
      updated_at = parse_numeric_date(e['updated_at'])

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

    def parse_numeric_date d
      # Every numeric date value that comes across is going to be Eastern Time
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

    def process_dates e, entry
      dates = Array.wrap(e[:dates])

      dates.each do |date_field|
        date = parse_numeric_date(date_field[:date])
        case date_field[:date_no]
        when 19
          entry.release_date = date
        when 20
          entry.fda_release_date = date
        when 108
          entry.fda_transmit_date = date
        when 2014
          entry.final_delivery_date = date
        when 93002
          entry.fda_review_date = date
        end
      end
    end
end; end; end;