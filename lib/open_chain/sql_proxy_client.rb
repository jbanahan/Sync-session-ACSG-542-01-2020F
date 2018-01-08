require 'open_chain/field_logic'
require 'open_chain/json_http_client'

module OpenChain; class SqlProxyClient

  def initialize json_client = OpenChain::JsonHttpClient.new
    @json_client = json_client
  end
 
  def request job_name, job_params, request_context, request_params = {}
    request_params = {swallow_error: true}.merge request_params
    request_body = {'job_params' => job_params}
    request_body['context'] = request_context unless request_context.blank?

    begin
      config = self.class.proxy_config[Rails.env]
      @json_client.post "#{config['url']}/job/#{job_name}", request_body, {}, config['auth_token']
    rescue => e
      raise e if request_params[:swallow_error] === false
      e.log_me ["Failed to initiate sql_proxy query for #{job_name} with params #{request_body.to_json}."]
      nil
    end
  end

  def report_query query_name, query_params = {}, context = {}
    # We actually want this to raise an error so that it's reported in the report result, rather than just left hanging out there in a "Running" state
    request query_name, query_params, context, swallow_error: false
  end

  def self.proxy_config
    @proxy_config ||= begin
      YAML.load_file self.proxy_config_file
    rescue Errno::ENOENT
      # do nothing...if the load raises we'll report a nicer error
    end
    raise "No SQL Proxy client configuration file found at '#{self.proxy_config_file}'." unless @proxy_config
    @proxy_config
  end

end; end
