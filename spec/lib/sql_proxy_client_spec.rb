require 'spec_helper'
require 'open_chain/sql_proxy_client'

describe OpenChain::SqlProxyClient do
  before :each do
    @http_client = double("MockHttpClient")
    @c = described_class.new @http_client
  end


  describe "request_alliance_invoice_details" do
    it "requests invoice details from alliance" do
      request_context = {'content' => 'context'}
      request_body = {'sql_params' => {:file_number=>123, :suffix=>"suffix"}, 'context' => request_context}
      @http_client.should_receive(:post).with("#{OpenChain::SqlProxyClient::PROXY_CONFIG['test']['url']}/query/invoice_details", request_body, {}, OpenChain::SqlProxyClient::PROXY_CONFIG['test']['auth_token'])
      
      @c.request_alliance_invoice_details "123", "suffix     ", request_context
    end

    it "strips blank suffixes down to blank string" do
      request_body = {'sql_params' => {:file_number=>123, :suffix=>' '}}
      @http_client.should_receive(:post).with("#{OpenChain::SqlProxyClient::PROXY_CONFIG['test']['url']}/query/invoice_details", request_body, {}, OpenChain::SqlProxyClient::PROXY_CONFIG['test']['auth_token'])

      @c.request_alliance_invoice_details "123", "     "
    end

    it "doesn't send context if a blank one is provided" do
      request_body = {'sql_params' => {:file_number=>123, :suffix=>'A'}}
      @http_client.should_receive(:post).with("#{OpenChain::SqlProxyClient::PROXY_CONFIG['test']['url']}/query/invoice_details", request_body, {}, OpenChain::SqlProxyClient::PROXY_CONFIG['test']['auth_token'])

      @c.request_alliance_invoice_details "123", "A"
    end
  end

  describe "request_alliance_invoice_numbers_since" do
    it "requests invoice numbers since given date" do
      request_body = {'sql_params' => {:invoice_date=>20140101}}
      @http_client.should_receive(:post).with("#{OpenChain::SqlProxyClient::PROXY_CONFIG['test']['url']}/query/find_invoices", request_body, {}, OpenChain::SqlProxyClient::PROXY_CONFIG['test']['auth_token'])

      @c.request_alliance_invoice_numbers_since Date.new(2014,1,1)
    end
  end

  describe "request_alliance_entry_details" do
    it "requests alliance entry details" do
      last_exported_date = Time.zone.now
      body = {'sql_params' => {:file_number => 12345}, 'context' => {'broker_reference' => '12345', 'last_exported_from_source' => last_exported_date.in_time_zone("Eastern Time (US & Canada)")}}

      @http_client.should_receive(:post).with("#{OpenChain::SqlProxyClient::PROXY_CONFIG['test']['url']}/query/entry_details", body, {}, OpenChain::SqlProxyClient::PROXY_CONFIG['test']['auth_token'])
      @c.request_alliance_entry_details "12345", last_exported_date
    end
  end

  describe "report_query" do
    it "requests running a query" do
      params = {"1"=>"2"}
      context = {"id"=>"1"}

      body = {'sql_params' => params, "context" => context}
      @http_client.should_receive(:post).with("#{OpenChain::SqlProxyClient::PROXY_CONFIG['test']['url']}/query/query_name", body, {}, OpenChain::SqlProxyClient::PROXY_CONFIG['test']['auth_token'])

      @c.report_query "query_name", params, context
    end

    it "raises errors encountered by the json client" do
      params = {"1"=>"2"}
      context = {"id"=>"1"}

      body = {'sql_params' => params, "context" => context}
      @http_client.should_receive(:post).with("#{OpenChain::SqlProxyClient::PROXY_CONFIG['test']['url']}/query/query_name", body, {}, OpenChain::SqlProxyClient::PROXY_CONFIG['test']['auth_token']).and_raise "JSON CLIENT ERROR"

      expect { @c.report_query "query_name", params, context }.to raise_error "JSON CLIENT ERROR"
    end
  end

  describe "request_advance_checks" do
    it "requests checks since given date" do
      now = Time.new 2014, 1, 1, 12, 30
      request_body = {'sql_params' => {:check_date=>20140101}}

      @http_client.should_receive(:post).with("#{OpenChain::SqlProxyClient::PROXY_CONFIG['test']['url']}/query/open_check_details", request_body, {}, OpenChain::SqlProxyClient::PROXY_CONFIG['test']['auth_token'])

      @c.request_advance_checks now
    end
  end
end