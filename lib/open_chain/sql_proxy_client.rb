require 'open_chain/json_http_client'

module OpenChain; class SqlProxyClient

  PROXY_CONFIG ||= YAML.load_file Rails.root.join('config', 'sql_proxy.yml')

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

    export = IntacctAllianceExport.where(file_number: file_number, suffix: suffix).first_or_create! data_requested_date: Time.zone.now
    # Alliance/Oracle won't return results if you send a blank string for suffix (since the data is stored like '        '), but will
    # return results if you send a single space instead.
    request 'invoice_details', {:file_number => file_number.to_i, :suffix => (suffix.blank? ? " " : suffix)}, request_context
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

  def self.request_advance_checks oldest_check_date
    self.new.request_advance_checks oldest_check_date
  end

  def request_advance_checks oldest_check_date
    request 'open_check_details', {:check_date => oldest_check_date.strftime("%Y%m%d").to_i}, {}
  end

  def self.request_file_tracking_info start_date, end_time
    self.new.request_file_tracking_info start_date, end_time
  end

  def request_file_tracking_info start_date, end_time
    request 'file_tracking', {:start_date => start_date.strftime("%Y%m%d").to_i, :end_time => end_time.strftime("%Y%m%d%H%M").to_i}, {}, results_as_array: true, swallow_error: false
  end

  def report_query query_name, query_params = {}, context = {}
    # We actually want this to raise an error so that it's reported in the report result, rather than just left hanging out there in a "Running" state
    request query_name, query_params, context, swallow_error: false
  end
 
  def request query_name, sql_params, request_context, request_params = {}
    request_params = {swallow_error: true}.merge request_params
    request_body = {'sql_params' => sql_params}
    request_body['context'] = request_context unless request_context.blank?
    if request_params[:results_as_array].to_s == "true"
      request_body['results_as_array'] = true
    end

    begin
      config = PROXY_CONFIG[Rails.env]
      @json_client.post "#{config['url']}/query/#{query_name}", request_body, {}, config['auth_token']
    rescue => e
      raise e if request_params[:swallow_error] === false
      e.log_me ["Failed to initiate sql_proxy query for #{query_name} with params #{request_body.to_json}."]
    end
  end

end; end