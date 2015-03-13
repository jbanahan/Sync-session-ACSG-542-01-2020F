require 'open_chain/sql_proxy_client'

module OpenChain; module CustomHandler; class KewillDataRequester

  def self.run_schedulable opts={}
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
    sql_proxy_client = (opts['sql_proxy_client'] ? opts['sql_proxy_client'] : OpenChain::SqlProxyClient.new)

    sql_proxy_client.request_updated_entry_numbers last_request, now

    # Only save the data once we're pretty sure the query to the sql proxy system was successful
    # This allows us to have the next run just re-request all the data if the query failed
    # for some reason (network outage, sql_query was down..etc)
    key.data = {'last_request' => now.strftime("%Y-%m-%d %H:%M")}
    key.save!
  end

  # This method requests all entry data from sql_proxy if the local entry data still shows an update time 
  # prior to the given time.  
  #
  # Basically, this is the handler for the data returned by the request made in the run_schedulable method.
  def self.request_entry_data broker_reference, expected_update_time, sql_proxy_client = OpenChain::SqlProxyClient.new
    # Before we actual do a sql proxy request, verify that in the intervening time between this job being queued 
    # and now that the entry hasn't been updated.
    time_zone = tz

    # Handle both the case of the update time being an int (.ie directly from the sql proxy update check query reponse)
    # or an actual ruby time object.
    if !expected_update_time.respond_to?(:acts_like_date)
      # The expected format of the time is YYYYmmDDHHMM (which parse handles fine)
      expected_update_time = time_zone.parse expected_update_time.to_s
    end

    # Just check for the id, if we get it back, it means the data hasn't been updated since being queued and we should make the request.

    # Pluck doesn't support multiple columns in Rails 3 - change to pluck when we go to 4
    e = Entry.where(broker_reference: broker_reference, source_system: OpenChain::AllianceParser::SOURCE_CODE).select([:expected_update_time, :last_exported_from_source]).first

    # If we didn't get any results, it means the entry hasn't come over yet...in that case, we should request the data
    if e.nil?
      send = true
    else
      send = (e.expected_update_time.nil? || e.expected_update_time.in_time_zone(time_zone) < expected_update_time) && 
                (e.last_exported_from_source.nil? || e.last_exported_from_source.in_time_zone(time_zone) < expected_update_time)
    end

    if send
      sql_proxy_client.request_entry_data broker_reference
    end
  end


  def self.tz 
    ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
  end
end; end; end