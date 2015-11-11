require 'open_chain/kewill_sql_proxy_client'

module OpenChain; module CustomHandler; class KewillDataRequester

  def self.run_schedulable opts={}
    if !opts['hours_ago'].blank?
      request_update_after_hours_ago opts['hours_ago'], opts
    else
      request_updated_since_last_run opts
    end
  end

  def self.request_update_after_hours_ago hours, opts = {}
    now = Time.zone.now
    start_time = now - hours.to_i.hours

    sql_proxy_client(opts).request_updated_entry_numbers start_time, now, customer_numbers_from_opts(opts)
  end

  def self.request_updated_since_last_run opts = {}
    key = KeyJsonItem.updated_entry_data('last_request').first_or_create! json_data: "{}"
    data = key.data
    last_request = data['last_request']

    time_zone = tz
    if last_request.nil?
      last_request = time_zone.now
    else
      # Turn the json data into an actual date object
      last_request = time_zone.parse last_request
    end

    now = time_zone.now

    # Apply the offset window, if present, to adjust the request start/end times by X seconds.
    # This is implemented to workaround data that is being written out while the data request is being done.
    # Alliance/Kewill Customs can take quite a while to write out entry data, and if we request to pull
    # the data while it's writing it out then we run the chance of missing pieces of it.  Thus, 
    # our "real-time" feed should only request data that was written a couple minutes ago.
    # Clearly, they're not using database transactions in that system - or if they are, aren't wrapping
    # the full data structure update in one.
    start_time, end_time = apply_offset(last_request, now, opts)
    sql_proxy_client(opts).request_updated_entry_numbers start_time, end_time, customer_numbers_from_opts(opts)

    # Only save the data once we're pretty sure the query to the sql proxy system was successful
    # This allows us to have the next run just re-request all the data if the query failed
    # for some reason (network outage, sql_query was down..etc)
    key.data = {'last_request' => now.strftime("%Y-%m-%d %H:%M")}
    key.save!
  end

  def self.customer_numbers_from_opts opts
    opts['customer_numbers'].blank? ? nil : opts['customer_numbers']
  end
  private_class_method :customer_numbers_from_opts

  def self.apply_offset start_time, end_time, opts
    offset = opts['offset'].to_i
    if offset != 0
      start_time = (start_time - offset.seconds)
      end_time = (end_time - offset.seconds)
    end
    [start_time, end_time]
  end
  private_class_method :apply_offset

  def self.sql_proxy_client opts
    (opts['sql_proxy_client'] ? opts['sql_proxy_client'] : OpenChain::KewillSqlProxyClient.new)
  end
  private_class_method :sql_proxy_client

  # This method requests all entry data from sql_proxy if the local entry data still shows an update time 
  # prior to the given time.  
  #
  # Basically, this is the handler for the data returned by the request made in the run_schedulable method.
  def self.request_entry_data broker_reference, expected_update_time, invoice_count, sql_proxy_client = OpenChain::KewillSqlProxyClient.new
    # Before we actual do a sql proxy request, verify that in the intervening time between this job being queued 
    # and now that the entry hasn't been updated.
    time_zone = tz

    # Handle both the case of the update time being an int (.ie directly from the sql proxy update check query reponse)
    # or an actual ruby time object.
    if !expected_update_time.respond_to?(:acts_like_date)
      # The expected format of the time is YYYYmmDDHHMM (which parse handles fine)
      expected_update_time = time_zone.parse expected_update_time.to_s
    end

    e = Entry.where(broker_reference: broker_reference, source_system: OpenChain::AllianceParser::SOURCE_CODE).select([:expected_update_time, :last_exported_from_source]).
          joins("LEFT OUTER JOIN broker_invoices ON broker_invoices.entry_id = entries.id").
          select("count(broker_invoices.id) 'invoice_count'").first

    # If we didn't get any results, it means the entry hasn't come over yet...in that case, we should request the data
    if e.nil?
      send = true
    else
      send = (e.expected_update_time.nil? || e.expected_update_time.in_time_zone(time_zone) < expected_update_time) && 
                (e.last_exported_from_source.nil? || e.last_exported_from_source.in_time_zone(time_zone) < expected_update_time)
    end

    # If the remote end shows it has more invoices than the local, then we should update the entry data, regardless of the 
    # expected update time involved...if the remote end doesn't have any invoices then it's pointless doing this check.
    if !send && e && invoice_count
      send = e.invoice_count.to_i < invoice_count
    end

    if send
      sql_proxy_client.request_entry_data broker_reference
    end
  end


  def self.tz 
    ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
  end

  def self.request_entry_batch_data json_request_data
    request_data = json_request_data.is_a?(String) ? ActiveSupport::JSON.decode(json_request_data) : json_request_data
    # the data being sent is just a large array w/ the key being the file number and the value being the update time of the file
    request_data.each_pair do |file_no, file_data|
      invoice_count = nil
      update_time = nil
      if file_data.is_a? Hash
        invoice_count = file_data['inv']
        update_time = file_data['date']
      else
        update_time = file_data
      end

      # Validate that this number hasn't already been queued in the DJ queue...method check done like this so we bomb if the method is
      # refactored away without updating this method
      if Delayed::Job.where("handler like ?", "%method_name: :#{self.method(:request_entry_data).name}%").where("handler like ?", "%'#{file_no}'%").count == 0
         OpenChain::CustomHandler::KewillDataRequester.delay.request_entry_data file_no, update_time, invoice_count
      end
    end
  end
end; end; end