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

  private 
    def request query_name, sql_params, request_context
      request_body = {'sql_params' => sql_params}
      request_body['context'] = request_context unless request_context.blank?

      begin
        config = PROXY_CONFIG[Rails.env]
        @json_client.post "#{config['url']}/query/#{query_name}", request_body, {}, config['auth_token']
      rescue => e
        e.log_me ["Failed to initiate sql_proxy query for #{query_name} with params #{request_body.to_json}."]
      end
    end

end; end