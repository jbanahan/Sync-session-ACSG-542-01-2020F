require 'spec_helper'
require 'open_chain/sql_proxy_client'

describe OpenChain::SqlProxyClient do
  before :each do
    @http_client = double("MockHttpClient")
    @c = described_class.new @http_client
    @proxy_config = {'test' => {'auth_token' => "config_auth_token", "url" => "config_url"}}
    described_class.stub(:proxy_config).and_return(@proxy_config)
  end


  describe "request_alliance_invoice_details" do
    it "requests invoice details from alliance" do
      request_context = {'content' => 'context'}
      request_body = {'job_params' => {:file_number=>123, :suffix=>"suffix"}, 'context' => request_context}
      @http_client.should_receive(:post).with("#{@proxy_config['test']['url']}/job/invoice_details", request_body, {}, @proxy_config['test']['auth_token'])
      
      @c.request_alliance_invoice_details "123", "suffix     ", request_context
    end

    it "strips blank suffixes down to blank string" do
      request_body = {'job_params' => {:file_number=>123, :suffix=>' '}}
      @http_client.should_receive(:post).with("#{@proxy_config['test']['url']}/job/invoice_details", request_body, {}, @proxy_config['test']['auth_token'])

      @c.request_alliance_invoice_details "123", "     "
    end

    it "doesn't send context if a blank one is provided" do
      request_body = {'job_params' => {:file_number=>123, :suffix=>'A'}}
      @http_client.should_receive(:post).with("#{@proxy_config['test']['url']}/job/invoice_details", request_body, {}, @proxy_config['test']['auth_token'])

      @c.request_alliance_invoice_details "123", "A"
    end

    it "raises error on errored post" do
      @http_client.should_receive(:post).and_raise "Error"
      expect{@c.request_alliance_invoice_details "123", "A"}.to raise_error "Error"
    end
  end

  describe "request_alliance_invoice_numbers_since" do
    it "requests invoice numbers since given date" do
      request_body = {'job_params' => {:invoice_date=>20140101}}
      @http_client.should_receive(:post).with("#{@proxy_config['test']['url']}/job/find_invoices", request_body, {}, @proxy_config['test']['auth_token'])

      @c.request_alliance_invoice_numbers_since Date.new(2014,1,1)
    end
  end

  describe "request_alliance_entry_details" do
    it "requests alliance entry details" do
      last_exported_date = Time.zone.now
      body = {'job_params' => {:file_number => 12345}, 'context' => {'broker_reference' => '12345', 'last_exported_from_source' => last_exported_date.in_time_zone("Eastern Time (US & Canada)")}}

      @http_client.should_receive(:post).with("#{@proxy_config['test']['url']}/job/entry_details", body, {}, @proxy_config['test']['auth_token'])
      @c.request_alliance_entry_details "12345", last_exported_date
    end
  end

  describe "report_query" do
    it "requests running a query" do
      params = {"1"=>"2"}
      context = {"id"=>"1"}

      body = {'job_params' => params, "context" => context}
      @http_client.should_receive(:post).with("#{@proxy_config['test']['url']}/job/query_name", body, {}, @proxy_config['test']['auth_token'])

      @c.report_query "query_name", params, context
    end

    it "raises errors encountered by the json client" do
      params = {"1"=>"2"}
      context = {"id"=>"1"}

      body = {'job_params' => params, "context" => context}
      @http_client.should_receive(:post).with("#{@proxy_config['test']['url']}/job/query_name", body, {}, @proxy_config['test']['auth_token']).and_raise "JSON CLIENT ERROR"

      expect { @c.report_query "query_name", params, context }.to raise_error "JSON CLIENT ERROR"
    end
  end

  describe "request_check_details" do
    it "requests check details" do
      request_body = {'job_params' => {file_number: 123, check_number: 456, check_date: 20141101, bank_number: 10, check_amount: 101}}

      @http_client.should_receive(:post).with("#{@proxy_config['test']['url']}/job/check_details", request_body, {}, @proxy_config['test']['auth_token'])
      @c.request_check_details "123", "456", Date.new(2014, 11, 1), "10", BigDecimal.new("1.01999").to_s
    end

    it "raises error on failed json post" do
      @http_client.should_receive(:post).and_raise "Error"
      expect{@c.request_check_details "123", "456", Date.new(2014, 11, 1), "10", BigDecimal.new("123")}.to raise_error "Error"
    end
  end

  describe "request_file_tracking_info" do
    it "requests files between given times" do
      start = Time.zone.now
      end_t = start + 1.hour

      request_body = {'job_params' => {start_date: start.strftime("%Y%m%d").to_i, end_date: end_t.strftime("%Y%m%d").to_i, end_time: end_t.strftime("%Y%m%d%H%M").to_i}, 'context'=>{results_as_array: true}}
      @http_client.should_receive(:post).with("#{@proxy_config['test']['url']}/job/file_tracking", request_body, {}, @proxy_config['test']['auth_token'])

      @c.request_file_tracking_info start, end_t
    end
  end

  describe "request_updated_entry_numbers" do
    it "requests updated entry data for given time period" do
      start = Time.zone.now.in_time_zone("Eastern Time (US & Canada)")
      end_t = start + 1.hour

      request_body = {'job_params' => {start_date: start.strftime("%Y%m%d%H%M"), end_date: end_t.strftime("%Y%m%d%H%M")}}
      @http_client.should_receive(:post).with("#{@proxy_config['test']['url']}/job/updated_entries", request_body, {}, @proxy_config['test']['auth_token'])
      @c.request_updated_entry_numbers start, end_t, ""
    end

    it "adds customer numbers to request if present" do
      start = Time.zone.now.in_time_zone("Eastern Time (US & Canada)")
      end_t = start + 1.hour

      request_body = {'job_params' => {start_date: start.strftime("%Y%m%d%H%M"), end_date: end_t.strftime("%Y%m%d%H%M"), customer_numbers: "CUST1, CUST2"}}
      @http_client.should_receive(:post).with("#{@proxy_config['test']['url']}/job/updated_entries", request_body, {}, @proxy_config['test']['auth_token'])
      @c.request_updated_entry_numbers start, end_t, "CUST1, CUST2"
    end
  end
end