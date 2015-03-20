require 'spec_helper'

describe OpenChain::CustomHandler::KewillEntryParser do

  def tz
    ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
  end

  describe "parse" do

    before :each do
      @e = {
        'cust_no' => 'TEST',
        'file_no' => 12345,
        'cr_certification_output_mess' => 'CERT MESSAGE',
        'fda_output_mess' => 'FDA MESSAGE',
        'updated_at' => 201502120600,
        'extract_time' => '2015-03-12T13:26:20-04:00',
        'dates' => [
          # Note the time ending in 60..stupid Alliance has dates w/ a minute value of 60 rather
          # than incrementing the hour.
          {'date_no'=>19, 'date'=>201503010660},
          {'date_no'=>20, 'date'=>201503020600},
          {'date_no'=>108, 'date'=>201503030600},
          {'date_no'=>2014, 'date'=>201503040600},
          {'date_no'=>93002, 'date'=>201503050600}
        ]
      }
      @json = {'entry'=>@e}
    end

    it "creates an entry using json data" do
       entry = described_class.parse @json.to_json

       expect(entry).to be_persisted
       expect(entry.broker_reference).to eq "12345"
       expect(entry.source_system).to eq "Alliance"
       expect(entry.release_cert_message).to eq "CERT MESSAGE"
       expect(entry.fda_message).to eq "FDA MESSAGE"

       expect(entry.expected_update_time).to eq tz.parse "201502120600"
       expect(entry.release_date).to eq tz.parse "201503010700"
       expect(entry.fda_release_date).to eq tz.parse "201503020600"
       expect(entry.fda_transmit_date).to eq tz.parse "201503030600"
       expect(entry.final_delivery_date).to eq tz.parse "201503040600"
       expect(entry.fda_review_date).to eq tz.parse "201503050600"
    end

    it "updates an entry using json data" do
      # Make sure we're not clearing out any information in a entry that's already there.
      # For the moment, this class should only be additive.
      t = Factory(:commercial_invoice_tariff)
      e = t.commercial_invoice_line.entry
      e.update_attributes! source_system: "Alliance", broker_reference: "REF"
      @e['file_no'] = e.broker_reference

      Factory(:broker_invoice_line, broker_invoice: Factory(:broker_invoice, entry: e))

      entry = described_class.parse @json.to_json

      expect(entry).to be_persisted
      expect(entry.broker_reference).to eq e.broker_reference
      expect(entry.release_cert_message).to eq "CERT MESSAGE"
    end

    it "uses cross process locking / per entry locking" do
      Lock.should_receive(:acquire).with(Lock::ALLIANCE_PARSER, times: 3).and_yield
      Lock.should_receive(:with_lock_retry).with(instance_of(Entry)).and_yield

      entry = described_class.parse @json.to_json
      expect(entry).to be_persisted
    end

    it "does not update data with a newer expected update time" do
      e = Factory(:entry, broker_reference: @e['file_no'], source_system: "Alliance", expected_update_time: Time.zone.now)
      expect(described_class.parse @json.to_json).to be_nil
    end

    it "does not update data with a newer last exported from source date" do
      e = Factory(:entry, broker_reference: @e['file_no'], source_system: "Alliance", last_exported_from_source: Time.zone.now)
      expect(described_class.parse @json.to_json).to be_nil
    end
  end
end