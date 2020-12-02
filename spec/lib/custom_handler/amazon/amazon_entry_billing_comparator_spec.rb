describe OpenChain::CustomHandler::Amazon::AmazonEntryBillingComparator do

  subject { described_class }

  describe "accept?" do
    let (:entry) {
      e = create(:entry, customer_number: "AMZN-1234", source_system: "Alliance")
      e.broker_invoices << create(:broker_invoice)
      e
    }

    let (:user) { create(:user) }

    let (:entry_snapshot) {
      entry.create_snapshot user
    }

    it "accepts any entry with broker invoices for a customer starting with AMZN" do
      expect(subject.accept? entry_snapshot).to eq true
    end

    it "does not accept non-Alliance entries" do
      entry.update! source_system: "Not Alliance"
      expect(subject.accept? entry_snapshot).to eq false
    end

    it "does not accept entries without invoices" do
      entry.broker_invoices.destroy_all
      expect(subject.accept? entry_snapshot).to eq false
    end

    it "does not accept non-AMZN entries" do
      entry.update! customer_number: "XXX"
      expect(subject.accept? entry_snapshot).to eq false
    end
  end

  describe "compare" do
    let (:generator) { instance_double(OpenChain::CustomHandler::Amazon::AmazonBillingFileGenerator) }
    let (:json) { instance_double(Hash) }

    it "retrieves json and sends with generator" do
      expect(subject).to receive(:generator).and_return generator
      expect(generator).to receive(:generate_and_send).with(json)
      expect(subject).to receive(:get_json_hash).with("bucket", "path", "version").and_return json

      subject.compare nil, nil, nil, nil, nil, "bucket", "path", "version"

    end
  end
end