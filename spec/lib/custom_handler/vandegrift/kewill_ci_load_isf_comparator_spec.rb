describe OpenChain::CustomHandler::Vandegrift::KewillCiLoadIsfComparator do

  subject { described_class }

  let (:isf) {
    isf = SecurityFiling.new host_system: "Kewill", status_code: "ACCMATCH", broker_customer_number: "CUST"
    line = isf.security_filing_lines.build
    isf
  }

  let! (:data_cross_reference) {
    DataCrossReference.add_xref! DataCrossReference::ISF_CI_LOAD_CUSTOMERS, "CUST", nil
  }

  describe "accept?" do

    let (:snapshot) {
      EntitySnapshot.new recordable: isf
    }

    it "accepts a matched Kewill ISF snapshot with lines" do
      expect(subject.accept? snapshot).to eq true
    end

    it "rejects if isf is not matched" do
      isf.status_code = "ACCNOMATCH"
      expect(subject.accept? snapshot).to eq false
    end

    it "rejects if isf is not from kewill" do
      isf.host_system = "Not Kewill"
      expect(subject.accept? snapshot).to eq false
    end

    it "rejects if isf does not have a customer number" do
      isf.broker_customer_number = ""
      expect(subject.accept? snapshot).to eq false
    end

    it "rejects if isf has no lines" do
      isf.security_filing_lines.delete_all
      expect(subject.accept? snapshot).to eq false
    end

    it "rejects if customer is not configured for isf CI Load sending" do
      data_cross_reference.delete
      expect(subject.accept? snapshot).to eq false
    end

    it "rejects if snapshot is not for a security filing" do
      expect(subject.accept? EntitySnapshot.new(recordable: Entry.new)).to eq false
    end
  end

  describe "compare" do

    before(:each) {
      isf.save!
    }

    it "generates and sends an isf that has not been sent" do
      expect_any_instance_of(OpenChain::CustomHandler::Vandegrift::KewillGenericIsfCiLoadGenerator).to receive(:generate_and_send).with isf
      subject.compare nil, isf.id, nil, nil, nil, nil, nil, nil

      expect(isf.sync_records.length).to eq 1
      sr = isf.sync_records.first
      expect(sr.persisted?).to eq true
      expect(sr.trading_partner).to eq "CI LOAD"
      expect(sr.sent_at).not_to be_nil
      expect(sr.confirmed_at).not_to be_nil
    end

    it "does not send if isf has already been sent" do
      expect_any_instance_of(OpenChain::CustomHandler::Vandegrift::KewillGenericIsfCiLoadGenerator).not_to receive(:generate_and_send)
      isf.sync_records.create! trading_partner: "CI LOAD", sent_at: Time.zone.now

      subject.compare nil, isf.id, nil, nil, nil, nil, nil, nil
    end

    it "can use an alternate ci load generator" do
      data_cross_reference.update_attributes! value: "OpenChain::CustomHandler::Vandegrift::KewillGenericShipmentCiLoadGenerator"
      expect_any_instance_of(OpenChain::CustomHandler::Vandegrift::KewillGenericShipmentCiLoadGenerator).to receive(:generate_and_send).with isf
      subject.compare nil, isf.id, nil, nil, nil, nil, nil, nil
    end

    it "can resend isf if sync record sent_at is cleared" do
      expect_any_instance_of(OpenChain::CustomHandler::Vandegrift::KewillGenericIsfCiLoadGenerator).to receive(:generate_and_send).with isf
      isf.sync_records.create! trading_partner: "CI LOAD"
      subject.compare nil, isf.id, nil, nil, nil, nil, nil, nil
      expect(isf.sync_records.length).to eq 1
      sr = isf.sync_records.first
      expect(sr.sent_at).not_to be_nil
    end
  end
end