require 'open_chain/sql_proxy_client'
require 'open_chain/field_logic'

module OpenChain; class KewillSqlProxyClient < SqlProxyClient

  def self.proxy_config_file
    Rails.root.join('config', 'sql_proxy.yml')
  end

  # For dj purposes
  def self.request_alliance_invoice_numbers_since invoice_date, request_context = {}
    self.new.request_alliance_invoice_numbers_since invoice_date, request_context
  end

  def request_alliance_invoice_numbers_since invoice_date, request_context = {}
    # Invoice Date is a Numeric value in alliance.
    request 'find_invoices', {:invoice_date => invoice_date.strftime("%Y%m%d").to_i}, request_context
  end

  # For dj purposes
  def self.request_alliance_invoice_details file_number, suffix, request_context = {}
    self.new.request_alliance_invoice_details file_number, suffix, request_context
  end

  def request_alliance_invoice_details file_number, suffix, request_context = {}
    # Alliance stores the suffix as blank strings...we want that locally as nil in our DB
    suffix = suffix.blank? ? nil : suffix.strip
    # Alliance/Oracle won't return results if you send a blank string for suffix (since the data is stored like '        '), but will
    # return results if you send a single space instead.
    request 'invoice_details', {:file_number => file_number.to_i, :suffix => (suffix.blank? ? " " : suffix)}, request_context, swallow_error: false
  end

  def self.request_check_details file_number, check_number, check_date, bank_number, check_amount, request_context = {}
    self.new.request_check_details file_number, check_number, check_date, bank_number, check_amount, request_context
  end

  def request_check_details file_number, check_number, check_date, bank_number, check_amount, request_context = {}
    # We're intentionally NOT including the suffix here, because for some reason, Alliance does NOT associate the check data
    # in the AP File table w/ any file suffix (it's always blank).  The File #, Check #, Check Date, etc are enough to ensure
    # a unique request, so that's fine.

    # Check Amounts are stored sans decimal points, so multiply the amount by 100 and strip any remaining decimal information
    # The BigDecimal.new stuff is a workaround for a delayed_job bug in serializing BigDecimals as floats...so we pass amount as a string
    amt = (BigDecimal.new(check_amount) * 100).truncate

    request 'check_details', {:file_number => file_number.to_i, check_number: check_number.to_i, 
                                check_date: check_date.strftime("%Y%m%d").to_i, bank_number: bank_number.to_i, check_amount: amt}, request_context, swallow_error: false
  end

  def self.request_alliance_entry_details file_number, last_exported_from_source
    self.new.request_alliance_entry_details file_number, last_exported_from_source
  end

  def request_alliance_entry_details file_number, last_exported_from_source
    # We're sending this context so that when the results are sent back to us from sql proxy's postback job
    # we can determine if the data in the postback is still valid or if there should be another request forthcoming.

    # Make sure we're keeping the timezone we're sending in eastern time (the alliance parser expects it that way)
    request_context = {"broker_reference" => file_number, "last_exported_from_source" => last_exported_from_source.in_time_zone("America/New_York")}
    request 'entry_details', {:file_number => file_number.to_i}, request_context
  end

  def self.request_file_tracking_info start_date, end_time
    self.new.request_file_tracking_info start_date, end_time
  end

  def request_file_tracking_info start_date, end_time
    request 'file_tracking', {:start_date => start_date.strftime("%Y%m%d").to_i, :end_date => end_time.strftime("%Y%m%d").to_i, :end_time => end_time.strftime("%Y%m%d%H%M").to_i}, {results_as_array: true}, swallow_error: false
  end

  def request_entry_data file_no
    request 'entry_data', {file_no: file_no.to_i}, {}
  end

  def self.delayed_bulk_entry_data search_run_id, primary_keys
    # We need to evaluate the search to get the keys BEFORE delaying the request to the backend queue,
    # otherwise, the search may change prior to the job being processed and then the wrong files get requested.
    if search_run_id.to_i != 0
      params = {sr_id: search_run_id}
      OpenChain::BulkUpdateClassification.replace_search_result_key params
      self.delay.bulk_request_entry_data s3_bucket: params[:s3_bucket], s3_key: params[:s3_key]
    else
      self.delay.bulk_request_entry_data primary_keys: primary_keys
    end
  end

  def self.bulk_request_entry_data primary_keys: nil, s3_bucket: nil, s3_key: nil
    c = self.new
    OpenChain::CoreModuleProcessor.bulk_objects(CoreModule::ENTRY, primary_keys: primary_keys, primary_key_file_bucket: s3_bucket, primary_key_file_path: s3_key) do |good_count, entry|
      c.request_entry_data entry.broker_reference if entry.source_system == "Alliance"
    end
  end

  # Requests sql proxy return a list of entry numbers that were updated 
  # during the timeframe specified by the parameters.  Which are expected 
  # to be Time objects.
  def request_updated_entry_numbers updated_since, updated_before, customer_numbers = nil
    updated_since = updated_since.in_time_zone("America/New_York").strftime "%Y%m%d%H%M"
    updated_before = updated_before.in_time_zone("America/New_York").strftime "%Y%m%d%H%M"
    params = {start_date: updated_since, end_date: updated_before}
    params[:customer_numbers] = csv_customer_list(customer_numbers) unless customer_numbers.blank?

    request 'updated_entries', params, {}, {swallow_error: false}
  end

  def request_mid_updates updated_after_date
    params = {updated_date: updated_after_date.strftime("%Y%m%d").to_i}
    context = {results_as_array: true}

    request "mid_updates", params, context, {swallow_error: false}
  end

  def request_address_updates updated_after_date
    params = {updated_date: updated_after_date.strftime("%Y%m%d").to_i}
    context = {results_as_array: true}

    request "address_updates", params, context, {swallow_error: false}
  end

  def request_updated_statements updated_after_date, updated_before_date, s3_bucket, s3_path, sqs_queue, customer_numbers: nil
    updated_since = updated_after_date.in_time_zone("America/New_York").strftime "%Y%m%d%H%M"
    updated_before = updated_before_date.in_time_zone("America/New_York").strftime "%Y%m%d%H%M"
    params = {start_date: updated_since, end_date: updated_before}
    params[:customer_numbers] = csv_customer_list(customer_numbers) unless customer_numbers.blank?

    context = {s3_bucket: s3_bucket, s3_path: s3_path, sqs_queue: sqs_queue}

    request 'updated_statements_to_s3', params, context, {swallow_error: false}
  end

  def csv_customer_list customers
    # Remove the newline that to_csv adds
    Array.wrap(customers).to_csv.strip
  end

end; end;