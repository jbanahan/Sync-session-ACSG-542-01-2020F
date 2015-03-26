require 'spec_helper'

describe OpenChain::CustomHandler::KewillEntryParser do

  def tz
    ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
  end

  describe "parse" do

    before :each do
      OpenChain::AllianceImagingClient.stub(:request_images)

      @e = {
        'cust_no' => 'TEST',
        'file_no' => 12345,
        'entry_no' => '316123456',
        'cr_certification_output_mess' => 'CERT MESSAGE',
        'fda_output_mess' => 'FDA MESSAGE',
        'updated_at' => 201502120600,
        'extract_time' => '2015-03-12T13:26:20-04:00',
        'dates' => [
          # Note the time ending in 60..stupid Alliance has dates w/ a minute value of 60 rather
          # than incrementing the hour.
          {'date_no'=>1, 'date'=>201503010660},
          {'date_no'=>3, 'date'=>201503010800},
          {'date_no'=>4, 'date'=>201503010900},
          {'date_no'=>9, 'date'=>201503011000},
          # Add 2 IT Dates, since we only want to log the first
          {'date_no'=>9, 'date'=>201503081000},
          {'date_no'=>11, 'date'=>201503011100},
          {'date_no'=>12, 'date'=>201503011200},
          {'date_no'=>16, 'date'=>201503011300},
          {'date_no'=>19, 'date'=>201503011400},
          {'date_no'=>20, 'date'=>201503011500},
          {'date_no'=>24, 'date'=>201503011600},
          {'date_no'=>25, 'date'=>201503011700},
          {'date_no'=>26, 'date'=>201503011800},
          {'date_no'=>28, 'date'=>201503011900},
          {'date_no'=>32, 'date'=>201503012000},
          {'date_no'=>42, 'date'=>201503012100},
          {'date_no'=>48, 'date'=>201503012200},
          {'date_no'=>52, 'date'=>201503012300},
          {'date_no'=>85, 'date'=>201503020000},
          {'date_no'=>108, 'date'=>201503020100},
          {'date_no'=>121, 'date'=>201503020200},
          {'date_no'=>2014, 'date'=>201503020300},
          {'date_no'=>92007, 'date'=>201503020400},
          {'date_no'=>92008, 'date'=>201503020500},
          {'date_no'=>93002, 'date'=>201503020600},
          {'date_no'=>99212, 'date'=>201503020700},
          {'date_no'=>99310, 'date'=>201503020800},
          {'date_no'=>99311, 'date'=>201503020900},
          {'date_no'=>99202, 'date'=>201503021000}
        ],
        'notes' => [
          {'note' => "Document Image created for F7501F   7501 Form.", 'modified_by'=>"User1", 'date_updated' => 201503191930},
          {'note' => "Document Image created for FORM_N7501", 'modified_by'=>"User2", 'date_updated' => 201503201247}
        ]
      }
      @json = {'entry'=>@e}
    end

    it "creates an entry using json data" do
      OpenChain::AllianceImagingClient.should_receive(:request_images).with "12345"
      entry = described_class.parse @json.to_json

      expect(entry).to be_persisted
      expect(entry.broker_reference).to eq "12345"
      expect(entry.entry_number).to eq "316123456"
      expect(entry.source_system).to eq "Alliance"
      expect(entry.release_cert_message).to eq "CERT MESSAGE"
      expect(entry.fda_message).to eq "FDA MESSAGE"

      # This is the only field different that the value above, since it's testing
      # that we handle date times w/ 60 as a minute value correctly
      expect(entry.export_date).to eq tz.parse("201503010700").to_date
      expect(entry.docs_received_date).to eq tz.parse("201503010800").to_date
      expect(entry.file_logged_date).to eq tz.parse "201503010900"
      expect(entry.first_it_date).to eq tz.parse("201503011000").to_date
      expect(entry.eta_date).to eq tz.parse("201503011100").to_date
      expect(entry.arrival_date).to eq tz.parse "201503011200"
      expect(entry.entry_filed_date).to eq tz.parse "201503011300"
      expect(entry.release_date).to eq tz.parse "201503011400"
      expect(entry.fda_release_date).to eq tz.parse "201503011500"
      expect(entry.trucker_called_date).to eq tz.parse "201503011600"
      expect(entry.delivery_order_pickup_date).to eq tz.parse "201503011700"
      expect(entry.freight_pickup_date).to eq tz.parse "201503011800"
      expect(entry.last_billed_date).to eq tz.parse "201503011900"
      expect(entry.invoice_paid_date).to eq tz.parse "201503012000"
      expect(entry.duty_due_date).to eq tz.parse("201503012100").to_date
      expect(entry.daily_statement_due_date).to eq tz.parse("201503012200").to_date
      expect(entry.free_date).to eq tz.parse "201503012300"
      expect(entry.edi_received_date).to eq tz.parse("201503020000").to_date
      expect(entry.fda_transmit_date).to eq tz.parse "201503020100"
      expect(entry.daily_statement_approved_date).to eq tz.parse("201503020200").to_date
      expect(entry.final_delivery_date).to eq tz.parse "201503020300"
      expect(entry.isf_sent_date).to eq tz.parse "201503020400"
      expect(entry.isf_accepted_date).to eq tz.parse "201503020500"
      expect(entry.fda_review_date).to eq tz.parse "201503020600"
      expect(entry.first_entry_sent_date).to eq tz.parse "201503020700"
      expect(entry.monthly_statement_received_date).to eq tz.parse("201503020800").to_date
      expect(entry.monthly_statement_paid_date).to eq tz.parse("201503020900").to_date
      expect(entry.first_release_date).to eq tz.parse "201503021000"

      expect(entry.first_7501_print).to eq tz.parse "201503191930"
      expect(entry.last_7501_print).to eq tz.parse "201503201247"
    end

    it "handles 98 date for docs received" do
      @e['dates'] << {'date_no'=>98, 'date'=>201503310000}
      entry = described_class.parse @json.to_json
      expect(entry.docs_received_date).to eq tz.parse("201503310000").to_date
    end

    it "uses earliest it date value" do
      # Put an actual Date value in the entry here so that we're also making sure that
      # the earliest value is handing comparison against the actual entry itself
      e = Factory(:entry, broker_reference: @e['file_no'], source_system: "Alliance", first_it_date: Date.new(2016, 1, 1))
      entry = described_class.parse @json.to_json
      expect(entry.first_it_date).to eq tz.parse("201503011000").to_date
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