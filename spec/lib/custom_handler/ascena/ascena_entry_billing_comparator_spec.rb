describe OpenChain::CustomHandler::Ascena::AscenaEntryBillingComparator do
  subject { described_class }

  describe "accept?" do
    let (:user) { Factory(:master_user) }
    let (:entry) { Factory(:entry, customer_number: 'ASCE', source_system: "Alliance") }
    let (:snapshot) { EntitySnapshot.create!(recordable: entry, user: user) }
    

    it "accepts entry snapshots for ASCE account" do
      expect(subject.accept? snapshot).to be true
    end

    it "doesn't accept non-ascena entries" do
      entry.update_attributes! customer_number: "NOT-ASCE"
      expect(subject.accept? snapshot).to be false
    end

    it "doesn't accept non-kewill entries" do
      entry.update_attributes! source_system: "Not Alliance"
      expect(subject.accept? snapshot).to be false
    end
  end

  describe "compare" do
    let (:generator) {
      gen = instance_double(OpenChain::CustomHandler::Ascena::AscenaBillingInvoiceFileGenerator)
      expect(subject).to receive(:ascena_generator).and_return gen
      gen
    }

    it "retrieves snapshot json and forwards it to generator" do
      json = {"key" => "value"}

      expect(generator).to receive(:generate_and_send).with json
      expect(subject).to receive(:get_json_hash).with("new_bucket", "new_path", "new_version").and_return json

      subject.compare nil, nil, nil, nil, nil, "new_bucket", "new_path", "new_version"
    end
  end
end