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

      export = IntacctAllianceExport.where(file_number: "123", suffix: "suffix").first
      expect(export).to_not be_nil
      expect(export.data_requested_date).to be >= 1.minute.ago
    end

    it "strips blank suffixes down to blank string" do
      request_body = {'sql_params' => {:file_number=>123, :suffix=>' '}}
      @http_client.should_receive(:post).with("#{OpenChain::SqlProxyClient::PROXY_CONFIG['test']['url']}/query/invoice_details", request_body, {}, OpenChain::SqlProxyClient::PROXY_CONFIG['test']['auth_token'])

      @c.request_alliance_invoice_details "123", "     "

      export = IntacctAllianceExport.where(file_number: "123", suffix: nil).first
      expect(export).to_not be_nil
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
end