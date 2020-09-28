describe OpenChain::CustomHandler::Ascena::AscenaEntryBillingComparator do
  subject { described_class }

  describe "accept?" do
    let (:user) { Factory(:master_user) }
    let (:entry) { Factory(:entry, customer_number: 'ASCE', source_system: "Alliance", entry_filed_date: Date.new(2020, 3, 15)) }
    let (:snapshot) { EntitySnapshot.create!(recordable: entry, user: user) }

    it "accepts entry snapshots for ASCE account" do
      expect(subject.accept?(snapshot)).to be true
    end

    it "accepts entry snapshots for MAUR account beginning 5/7/19" do
      entry.update! customer_number: "MAUR", entry_filed_date: Date.new(2019, 5, 7)
      expect(subject.accept?(snapshot)).to be true
    end

    it "doesn't accept earlier MAUR snapshots" do
      entry.update! customer_number: "MAUR", entry_filed_date: Date.new(2019, 5, 1)
      expect(subject.accept?(snapshot)).to be false
    end

    it "doesn't accept FTZ (type 06) entries" do
      entry.update! entry_type: "06"
      expect(subject.accept?(snapshot)).to be false
    end

    it "doesn't accept ISF entries" do
      entry.update! customer_references: "October ISF"
      expect(subject.accept?(snapshot)).to be false

      entry.update! customer_references: "October is nice", entry_filed_date: nil
      expect(subject.accept?(snapshot)).to be nil
    end

    it "doesn't accept non-ascena entries" do
      entry.update! customer_number: "NOT-ASCE"
      expect(subject.accept?(snapshot)).to be false
    end

    it "doesn't accept non-kewill entries" do
      entry.update! source_system: "Not Alliance"
      expect(subject.accept?(snapshot)).to be false
    end
  end

  describe "compare" do
    let (:generator) do
      gen = instance_double(OpenChain::CustomHandler::Ascena::AscenaBillingInvoiceFileGenerator)
      expect(subject).to receive(:ascena_generator).and_return gen
      gen
    end

    it "retrieves snapshot json and forwards it to generator" do
      json = {"key" => "value"}

      expect(generator).to receive(:generate_and_send).with json
      expect(subject).to receive(:get_json_hash).with("new_bucket", "new_path", "new_version").and_return json

      subject.compare nil, nil, nil, nil, nil, "new_bucket", "new_path", "new_version"
    end
  end
end
