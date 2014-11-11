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
    # Alliance/Oracle won't return results if you send a blank string for suffix (since the data is stored like '        '), but will
    # return results if you send a single space instead.
    request 'invoice_details', {:file_number => file_number.to_i, :suffix => (suffix.blank? ? " " : suffix)}, request_context, false
  end

  def self.request_check_details file_number, check_number, check_date, bank_number, request_context = {}
    self.new.request_check_details file_number, check_number, check_date, bank_number, request_context
  end

  def request_check_details file_number, check_number, check_date, bank_number, request_context = {}
    # We're intentionally NOT including the suffix here, because for some reason, Alliance does NOT associate the check data
    # in the AP File table w/ any file suffix (it's always blank).  The File #, Check #, Check Date, etc are enough to ensure
    # a unique request, so that's fine.
    request 'check_details', {:file_number => file_number.to_i, check_number: check_number.to_i, 
                                check_date: check_date.strftime("%Y%m%d").to_i, bank_number: bank_number.to_i}, request_context, false
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

  def report_query query_name, query_params = {}, context = {}
    # We actually want this to raise an error so that it's reported in the report result, rather than just left hanging out there in a "Running" state
    request query_name, query_params, context, false
  end
 
  def request query_name, sql_params, request_context, swallow_error = true
    request_body = {'sql_params' => sql_params}
    request_body['context'] = request_context unless request_context.blank?

    begin
      config = PROXY_CONFIG[Rails.env]
      @json_client.post "#{config['url']}/query/#{query_name}", request_body, {}, config['auth_token']
    rescue => e
      raise e unless swallow_error
      e.log_me ["Failed to initiate sql_proxy query for #{query_name} with params #{request_body.to_json}."]
    end
  end

end; end