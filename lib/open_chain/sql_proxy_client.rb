require 'open_chain/json_http_client'
require 'open_chain/field_logic'

module OpenChain; class SqlProxyClient

  def initialize json_client = OpenChain::JsonHttpClient.new
    @json_client = json_client
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
    request_context = {"broker_reference" => file_number, "last_exported_from_source" => last_exported_from_source.in_time_zone("Eastern Time (US & Canada)")}
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

  def self.bulk_request_entry_data search_run_id, primary_keys
    c = self.new
    OpenChain::CoreModuleProcessor.bulk_objects(CoreModule::ENTRY,search_run_id,primary_keys) do |good_count, entry|
      c.request_entry_data entry.broker_reference if entry.source_system == "Alliance"
    end
  end

  # Requests sql proxy return a list of entry numbers that were updated 
  # during the timeframe specified by the parameters.  Which are expected 
  # to be Time objects.
  def request_updated_entry_numbers updated_since, updated_before, customer_numbers = nil
    updated_since = updated_since.in_time_zone("Eastern Time (US & Canada)").strftime "%Y%m%d%H%M"
    updated_before = updated_before.in_time_zone("Eastern Time (US & Canada)").strftime "%Y%m%d%H%M"
    params = {start_date: updated_since, end_date: updated_before}
    params[:customer_numbers] = customer_numbers unless customer_numbers.blank?

    request 'updated_entries', params, {}
  end

  def report_query query_name, query_params = {}, context = {}
    # We actually want this to raise an error so that it's reported in the report result, rather than just left hanging out there in a "Running" state
    request query_name, query_params, context, swallow_error: false
  end
 
  def request job_name, job_params, request_context, request_params = {}, retry_count = 3
    request_params = {swallow_error: true}.merge request_params
    request_body = {'job_params' => job_params}
    request_body['context'] = request_context unless request_context.blank?

    begin
      config = self.class.proxy_config[Rails.env]
      @json_client.post "#{config['url']}/job/#{job_name}", request_body, {}, config['auth_token']
    rescue => e
      raise e if request_params[:swallow_error] === false
      e.log_me ["Failed to initiate sql_proxy query for #{job_name} with params #{request_body.to_json}."]
    end
  end

  def self.proxy_config
    @@proxy_config ||= YAML.load_file Rails.root.join('config', 'sql_proxy.yml')
    raise "No SQL Proxy client configuration file found." unless @@proxy_config
    @@proxy_config
  end

end; end