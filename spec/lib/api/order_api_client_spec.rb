require 'spec_helper'

describe OpenChain::Api::OrderApiClient do
  subject { described_class.new('test', 'test', 'test') }
  let(:http_client) { double("OpenChain::JsonHttpClient") }


  describe "find_by_order_number" do
    it "uses the correct path" do
      expect(subject).to receive(:get).with("/orders/by_order_number", {order_number: "order", 'fields' => "ord_order_number"})
      subject.find_by_order_number "order", ["ord_order_number"]
    end

    it "transparently handles not found errors" do
      e = OpenChain::Api::ApiClient::ApiError.new(404, {})
      expect(subject).to receive(:get).and_raise e

      expect(subject.find_by_order_number "order", ["ord_order_number"]).to eq({'order'=>nil})
    end
  end

  describe "core_module" do
    it "uses correct core module" do
      expect(subject.core_module).to eq CoreModule::ORDER
    end
  end

end