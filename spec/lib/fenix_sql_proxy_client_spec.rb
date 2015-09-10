require 'spec_helper'

describe OpenChain::FenixSqlProxyClient do
  before :each do
    @http_client = double("MockHttpClient")
    @c = described_class.new @http_client
    @proxy_config = {'test' => {'auth_token' => "config_auth_token", "url" => "config_url"}}
    described_class.stub(:proxy_config).and_return(@proxy_config)
  end

  describe "request_images_added_between" do
    it "sends request using times in UTC" do
      tz = ActiveSupport::TimeZone["Hawaii"]
      start_date = "2015-09-09T16:00:00-10:00"
      end_date = "2015-09-09T16:05:00-10:00"

      subject.should_receive(:request).with('fenix_updated_documents', {start_date: "2015-09-10T02:00:00Z", end_date: "2015-09-10T02:05:00Z"}, {}, swallow_error: false)
      subject.request_images_added_between tz.parse(start_date), tz.parse(end_date)
    end
  end

  describe "request_images_for_transaction_number" do
    it "sends request" do
      subject.should_receive(:request).with('fenix_documents_for_transaction', {transaction_number: "12345"}, {}, swallow_error: false)
      subject.request_images_for_transaction_number("12345")
    end
  end
end