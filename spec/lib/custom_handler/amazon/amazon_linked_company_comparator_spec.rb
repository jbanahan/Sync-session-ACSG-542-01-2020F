describe OpenChain::CustomHandler::Amazon::AmazonLinkedCompanyComparator do
  let(:comp) { described_class }
  let!(:amazon) { FactoryBot(:company, system_code: "AMZN")}
  let!(:customer) { FactoryBot(:company, system_code: "AMZN-ACME")}
  let!(:entry) { FactoryBot(:entry, importer: customer, customer_number: "AMZN-ACME")}

  describe "accept?" do
    let!(:snap) { FactoryBot(:entity_snapshot, recordable: entry) }

    it "returns 'true' if entry is associated with a customer whose number begins AMZN and is not linked to Amazon" do
      expect(comp.accept? snap).to eq true
    end

    it "returns 'false' if customer number doesn't begin with AMZN" do
      entry.update! customer_number: "ACME"
      expect(comp.accept? snap).to eq false
    end

    it "returns 'false' if customer is already linked to Amazon" do
      amazon.linked_companies << customer
      expect(comp.accept? snap).to eq false
    end
  end

  describe "compare" do

    it "links entry's importer to Amazon" do
      comp.compare "Entry", entry.id, "old bucket", "new bucket", "old path", "new bucket", "new path", "new version"
      expect(amazon.linked_companies.count).to eq 1
      expect(amazon.linked_companies.first).to eq customer
    end

    it "doesn't throw an error if attempt is made to add importer twice" do
      amazon.linked_companies << customer
      expect { comp.compare "Entry", entry.id, "old bucket", "new bucket", "old path", "new bucket", "new path", "new version" }.to_not raise_error
      expect(amazon.linked_companies.count).to eq 1
    end
  end

end
