require 'spec_helper'

describe OpenChain::Api::OrderApiClient do
  subject { described_class.new('test', 'test', 'test') }
  let(:http_client) { double("OpenChain::JsonHttpClient") }


  describe "find_by_order_number" do
    it "uses the correct path" do
      expect(subject).to receive(:get).with("/orders/by_order_number", {order_number: "order", 'mf_uids' => "ord_order_number"})
      subject.find_by_order_number "order", ["ord_order_number"]
    end

    it "transparently handles not found errors" do
      e = OpenChain::Api::ApiClient::ApiError.new(404, {})
      expect(subject).to receive(:get).and_raise e

      expect(subject.find_by_order_number "order", ["ord_order_number"]).to eq({'order'=>nil})
    end
  end

  describe "show" do
    it "uses the correct path" do
      expect(subject).to receive(:get).with("/orders/1", {"mf_uids" => "ord_order_number"})
      subject.show(1, [:ord_order_number])
    end
  end

  describe "create" do
    it "uses the correct path" do
      expect(subject).to receive(:post).with("/orders", {"order"=>{}})
      subject.create({"order"=>{}})
    end
  end

  describe "update" do
    it "uses the correct path" do
      expect(subject).to receive(:put).with("/orders/1", {"order"=>{"id" => 1}})
      subject.update({"order"=>{"id" => 1}})
    end

    it "raises an error if id is not included" do
      expect {subject.update({"order"=>{}})}.to raise_error "All API update calls require an 'id' in the attribute hash."
    end
  end
end