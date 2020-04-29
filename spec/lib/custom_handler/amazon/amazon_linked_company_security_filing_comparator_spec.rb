describe OpenChain::CustomHandler::Amazon::AmazonLinkedCompanySecurityFilingComparator do

  subject { described_class }

  let!(:amazon) { Factory(:company, system_code: "AMZN")}
  let!(:customer) { Factory(:company, system_code: "AMZN-ACME")}
  let!(:isf) { Factory(:security_filing, importer: customer, importer_account_code: "AMZN-ACME")}

  describe "accept?" do
    let!(:snap) { Factory(:entity_snapshot, recordable: isf) }

    it "returns 'true' if isf is associated with a customer whose number begins AMZN and is not linked to Amazon" do
      expect(subject.accept? snap).to eq true
    end

    it "returns 'false' if customer number doesn't begin with AMZN" do
      isf.update! importer_account_code: "ACME"
      expect(subject.accept? snap).to eq false
    end

    it "returns 'false' if customer is already linked to Amazon" do
      amazon.linked_companies << customer
      expect(subject.accept? snap).to eq false
    end
  end

  describe "compare" do

    it "links isf's importer to Amazon" do
      subject.compare "SecurityFiling", isf.id, "old bucket", "new bucket", "old path", "new bucket", "new path", "new version"
      expect(amazon.linked_companies.count).to eq 1
      expect(amazon.linked_companies.first).to eq customer
    end

    it "doesn't throw an error if attempt is made to add importer twice" do
      amazon.linked_companies << customer
      expect { subject.compare "SecurityFiling", isf.id, "old bucket", "new bucket", "old path", "new bucket", "new path", "new version" }.to_not raise_error
      expect(amazon.linked_companies.count).to eq 1
    end
  end

end