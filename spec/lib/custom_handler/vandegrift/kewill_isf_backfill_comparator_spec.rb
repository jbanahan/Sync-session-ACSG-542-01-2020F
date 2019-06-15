describe OpenChain::CustomHandler::Vandegrift::KewillIsfBackfillComparator do
  subject { described_class }

  let(:us_country) { Factory(:country, iso_code: "US")}
  let(:non_us_country) { Factory(:country, iso_code: "CA")}
  let(:entry) { Factory(:entry, source_system: 'Alliance', import_country: us_country, transport_mode_code: 10, entry_number: '1234567890', master_bills_of_lading: '1234567890',
                        customer_number: '1234567890', broker_reference: '1234567890')}
  let!(:security_filing) { Factory(:security_filing, broker_customer_number: '1234567890', master_bill_of_lading: '1234567890')}

  describe "#compare" do

    it "appends the security filing's entry_reference_numbers and entry_number if new broker_reference is not present" do
      security_filing.update_attributes! entry_reference_numbers: "0987654321", entry_numbers: "0987654321"
      subject.compare(nil, entry.id, nil, nil, nil, nil, nil, nil)
      security_filing.reload
      expect(security_filing.entry_reference_numbers).to eql("0987654321\n 1234567890")
      expect(security_filing.entry_numbers).to eql("0987654321\n 1234567890")
    end

    it "sets the entry's security filing's entry_reference_numbers if not present" do
      subject.compare(nil, entry.id, nil, nil, nil, nil, nil, nil)
      security_filing.reload
      expect(security_filing.entry_reference_numbers).to eql('1234567890')
      expect(security_filing.entry_numbers).to eql('1234567890')
    end

    it "is not compared unless entry is valid" do
      expect(subject).to receive(:valid_entry?).and_return false
      expect(subject).not_to receive(:populate_isf_data)

      subject.compare(nil, entry.id, nil, nil, nil, nil, nil, nil)
    end

    it "falls back to matching on house bill if master bill is blank" do
      entry.update_attributes! house_bills_of_lading: "HBOL12345", master_bills_of_lading: ""
      security_filing.update_attributes! house_bills_of_lading: "HBOL12345", master_bill_of_lading: ""

      subject.compare(nil, entry.id, nil, nil, nil, nil, nil, nil)
      security_filing.reload
      expect(security_filing.entry_numbers).to eql('1234567890')
    end

    it "matches to ISF with house and master bills based soley on masterbill" do
      entry.update_attributes! house_bills_of_lading: "HBOL0000"
      security_filing.update_attributes! house_bills_of_lading: "HBOL12345"

      subject.compare(nil, entry.id, nil, nil, nil, nil, nil, nil)
      security_filing.reload
      expect(security_filing.entry_numbers).to eql('1234567890')
    end

    it "matches to ISF with blank master bill and houses" do
      entry.update_attributes! house_bills_of_lading: "HBOL12345"
      security_filing.update_attributes! house_bills_of_lading: "HBOL12345", master_bill_of_lading: ""

      subject.compare(nil, entry.id, nil, nil, nil, nil, nil, nil)
      security_filing.reload
      expect(security_filing.entry_numbers).to eql('1234567890')
    end

    it "does not match to ISF if master bill does not match and house bill matches" do
      entry.update_attributes! house_bills_of_lading: "HBOL12345", master_bills_of_lading: "NOT A MATCH"
      security_filing.update_attributes! house_bills_of_lading: "HBOL12345"

      subject.compare(nil, entry.id, nil, nil, nil, nil, nil, nil)
      security_filing.reload
      expect(security_filing.entry_numbers).to be_blank
    end

    context "with EDDIEFTZ mapping" do
      before :each do 
        entry.update_attributes! customer_number: "EDDIEFTZ"
      end

      it "matches to EBCC ISF files" do
        security_filing.update_attributes! broker_customer_number: "EBCC"
        subject.compare(nil, entry.id, nil, nil, nil, nil, nil, nil)
        security_filing.reload
        expect(security_filing.entry_reference_numbers).to eql('1234567890')
      end

      it "matches to EDDIE ISF files" do
        security_filing.update_attributes! broker_customer_number: "EDDIE"
        subject.compare(nil, entry.id, nil, nil, nil, nil, nil, nil)
        security_filing.reload
        expect(security_filing.entry_reference_numbers).to eql('1234567890')
      end
    end
  end

  describe "#find_security_filings" do
    it "finds only security filings that match customer number and master_bills_of_lading" do
      sf1 = Factory(:security_filing, master_bill_of_lading: '1234567890', broker_customer_number: '1234567890')
      sf2 = Factory(:security_filing, master_bill_of_lading: '0987654321', broker_customer_number: '0987654321')
      entry.customer_number = 1234567890
      entry.master_bills_of_lading = "1234567890"
      entry.broker_reference = "1234567890"
      entry.save
      entry.reload
      expect(subject.find_security_filings(entry)).to include(sf1)
      expect(subject.find_security_filings(entry)).to_not include(sf2)
    end
  end

  describe ".ocean_transport?" do
    it "returns true if transport_mode_code is 10" do
      entry.transport_mode_code = 10
      entry.save
      entry.reload
      expect(subject.ocean_transport?(entry)).to be_truthy
    end

    it "returns true if transport_mode_code is 11" do
      entry.transport_mode_code = 11
      entry.save
      entry.reload
      expect(subject.ocean_transport?(entry)).to be_truthy
    end

    it "returns false if transport_mode_code is neither 10 or 11" do
      entry.transport_mode_code = 12
      entry.save
      entry.reload
      expect(subject.ocean_transport?(entry)).to be_falsey
    end
  end

  describe ".us_entry?" do
    it "returns false if entry's source_system is not Alliance" do
      entry.source_system = "Source"
      entry.save
      entry.reload
      expect(subject.us_country?(entry)).to be_falsey
    end
  end

  describe "valid_entry" do
    let (:entry) {
      e = Entry.new transport_mode_code: "10", source_system: "Alliance", customer_number: "CUST", master_bills_of_lading: "MBOL"
    }
    it "returns true if entry is ocean mode Alliance entry with customer number and master bills" do
      expect(subject.valid_entry? entry).to eq true
    end

    it "returns true if alternate ocean mode is used" do
      entry.transport_mode_code = "11"
      expect(subject.valid_entry? entry).to eq true
    end

    it "returns false if not ocean mode" do
      entry.transport_mode_code = "40"
      expect(subject.valid_entry? entry).to eq false
    end

    it "returns false if not Alliance entry" do
      entry.source_system = "Not Alliance"
      expect(subject.valid_entry? entry).to eq false
    end

    it "returns false if customer number is blank" do
      entry.customer_number = nil
      expect(subject.valid_entry? entry).to eq false
    end

    it "returns false if master bill is blank and house bill is blank" do
      entry.master_bills_of_lading = nil
      expect(subject.valid_entry? entry).to eq false
    end

    it "returns true if master bill is blank but house bills has a value" do
      entry.master_bills_of_lading = nil
      entry.house_bills_of_lading = "HBOL"
      expect(subject.valid_entry? entry).to eq true
    end
  end
end
