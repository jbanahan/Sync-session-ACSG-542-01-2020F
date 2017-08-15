require 'spec_helper'

describe OpenChain::CustomHandler::Vandegrift::KewillIsfBackfillComparator do
  subject { described_class }

  let(:us_country) { Factory(:country, iso_code: "US")}
  let(:non_us_country) { Factory(:country, iso_code: "CA")}
  let(:entry) { Factory(:entry, source_system: 'Alliance', import_country: us_country, transport_mode_code: 10, entry_number: '1234567890', master_bills_of_lading: '1234567890',
                        customer_number: '1234567890', broker_reference: '1234567890')}
  let!(:security_filing) { Factory(:security_filing, broker_customer_number: '1234567890', master_bill_of_lading: '1234567890')}

  describe "#compare" do
    before do
      @klass = subject.new
      allow(subject).to receive(:new).and_return(@klass)
    end

    it "appends the security filing's entry_reference_numbers if new broker_reference is not present" do
      security_filing.entry_reference_numbers = "0987654321"
      security_filing.save!
      @klass.compare(entry)
      security_filing.reload
      expect(security_filing.entry_reference_numbers).to eql("0987654321\n1234567890")
    end

    it "sets the entry's security filing's entry_reference_numbers if not present" do
      @klass.compare(entry)
      security_filing.reload
      expect(security_filing.entry_reference_numbers).to eql('1234567890')
    end

    it "appends the security filing's entry_number if new entry_number is not present" do
      security_filing.entry_numbers = "0987654321"
      security_filing.save!
      @klass.compare(entry)
      security_filing.reload
      expect(security_filing.entry_numbers).to eql("0987654321\n1234567890")
    end

    it "sets the entry's security filing's entry_number if not present" do
      @klass.compare(entry)
      security_filing.reload
      expect(security_filing.entry_numbers).to eql('1234567890')
    end

    it "is not called if customer_number is blank" do
      entry.customer_number = nil
      entry.save
      entry.reload
      expect(@klass).to_not receive(:compare)
      subject.compare(nil, entry.id, nil, nil, nil, nil, nil, nil)
    end

    it "is not called if master_bills_of_lading is blank" do
      entry.master_bills_of_lading = nil
      entry.save
      entry.reload
      expect(@klass).to_not receive(:compare)
      subject.compare(nil, entry.id, nil, nil, nil, nil, nil, nil)
    end

    it "is not called if us_country? is false" do
      entry.source_system = "Kewill"
      entry.save
      entry.reload
      expect(@klass).to_not receive(:compare)
      subject.compare(nil, entry.id, nil, nil, nil, nil, nil, nil)
    end

    it "is not called if ocean_transport? is false" do
      entry.transport_mode_code = 12
      entry.save
      entry.reload
      expect(@klass).to_not receive(:compare)
      subject.compare(nil, entry.id, nil, nil, nil, nil, nil, nil)
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
      expect(subject.new.find_security_filings(entry)).to include(sf1)
      expect(subject.new.find_security_filings(entry)).to_not include(sf2)
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
end
