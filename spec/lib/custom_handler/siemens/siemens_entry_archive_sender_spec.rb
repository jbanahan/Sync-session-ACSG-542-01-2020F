describe OpenChain::CustomHandler::Siemens::SiemensEntryArchiveSender do

  let(:co1) do
    co = FactoryBot(:company)
    co.system_identifiers.create! system: "Fenix", code: "807150586RM0001"
    co
  end

  let(:co2) do
    co = FactoryBot(:company)
    co.system_identifiers.create! system: "Fenix", code: "807150586RM0002"
    co
  end

  let(:co3) do
    co = FactoryBot(:company)
    co.system_identifiers.create! system: "Fenix", code: "not siemens"
    co
  end

  let!(:sys_date) { SystemDate.create! date_type: "OpenChain::CustomHandler::Siemens::SiemensCaXmlBillingGenerator", start_date: Date.new(2020, 1, 5)}

  let(:yesterday) { Time.zone.now - (1.day + 1.minute) }
  let(:now) { Time.zone.now }

  let(:ent1) do
    ent = FactoryBot(:entry, broker_reference: "brok1", importer: co1, entry_number: "ent_num1", file_logged_date: Date.new(2020, 1, 6))
    ent.sync_records.create! trading_partner: described_class::XML_SYNC_TRADING_PARTNER, sent_at: yesterday, confirmed_at: yesterday + 1.minute
    ent
  end

  let(:ent2) do
    ent = FactoryBot(:entry, broker_reference: "brok2", importer: co2, entry_number: "ent_num2", file_logged_date: Date.new(2020, 1, 6))
    ent.sync_records.create! trading_partner: described_class::XML_SYNC_TRADING_PARTNER, sent_at: yesterday, confirmed_at: yesterday + 1.minute
    ent
  end

  let(:ent3) do
    ent = FactoryBot(:entry, broker_reference: "brok3", importer: co3, entry_number: "ent_num3", file_logged_date: Date.new(2020, 1, 6))
    # included to test importer -- non-Siemens entries would never have one of these
    ent.sync_records.create! trading_partner: described_class::XML_SYNC_TRADING_PARTNER, sent_at: yesterday, confirmed_at: yesterday + 1.minute
    ent
  end

  let(:att1) { FactoryBot(:attachment, attachable: ent1, attachment_type: "Archive Packet", created_at: yesterday - 1.minute) }
  let(:att2) { FactoryBot(:attachment, attachable: ent2, attachment_type: "Archive Packet", created_at: yesterday - 1.minute) }
  let(:att3) { FactoryBot(:attachment, attachable: ent3, attachment_type: "Archive Packet", created_at: yesterday - 1.minute) }
  let(:ms) { stub_master_setup }

  before do
    allow(ms).to receive(:production?).and_return true

    allow(MasterSetup).to receive(:secrets).and_return({"siemens" => {"partner_id" => "1005029"}})

    att1; att2; att3

    [ent1, ent2, ent3].each { |ent| FactoryBot(:broker_invoice, entry: ent, invoice_date: "2020-03-15") }

    allow_any_instance_of(Attachment).to receive(:bucket) do |att|
      if att.id == att1.id
        "bucket1"
      elsif att.id == att2.id
        "bucket2"
      end
    end

    allow_any_instance_of(Attachment).to receive(:path) do |att|
      if att.id == att1.id
        "path1"
      elsif att.id == att2.id
        "path2"
      end
    end
  end

  describe "run_schedulable" do
    it "executes process_entries" do
      today = now.beginning_of_day
      sys_date.update! start_date: today

      expect_any_instance_of(described_class).to receive(:process_entries) do |sender|
        expect(sender.start_date).to eq today
      end

      described_class.run_schedulable
    end
  end

  describe "process_entries" do
    let(:now) { DateTime.new 2020, 3, 15 }

    it "sends archives" do
      buckets = []
      allow(Helpers::MockS3).to receive(:download_to_tempfile) do |bucket, path, opts, &block|
        buckets << bucket
        if bucket == "bucket1"
          expect(path).to eq "path1"
          expect(opts[:original_filename]).to eq "100502_CA_B3_119_ent_num1_20200315000000.pdf"
          block.call "archive_1"
        elsif bucket == "bucket2"
          expect(path).to eq "path2"
          expect(opts[:original_filename]).to eq "100502_CA_B3_119_ent_num2_20200315000000.pdf"
          block.call "archive_2"
        end
      end

      allow(subject).to receive(:connect_vfitrack_net).with("to_ecs/siemens_hc/docs").and_return "connect_hsh"
      allow(subject).to receive(:ftp_file).with "archive_1", "connect_hsh"
      allow(subject).to receive(:ftp_file).with "archive_2", "connect_hsh"

      Timecop.freeze(now) { subject.process_entries }

      # verify that only ent1 and ent2 were processed
      expect(buckets).to contain_exactly("bucket1", "bucket2")

      ent1.reload
      expect(ent1.sync_records.count).to eq 2
      sr1 = ent1.sync_records.find { |sr| sr.trading_partner == described_class::SYNC_TRADING_PARTNER }
      expect(sr1).not_to be_nil
      expect(sr1.sent_at).to eq now

      ent2.reload
      expect(ent2.sync_records.count).to eq 2
      sr2 = ent2.sync_records.find { |sr| sr.trading_partner == described_class::SYNC_TRADING_PARTNER }
      expect(sr2).not_to be_nil
      expect(sr2.sent_at).to eq now
    end

    it "recovers if entry processing throws exception" do
      buckets = []
      allow(Helpers::MockS3).to receive(:download_to_tempfile) do |bucket, path, opts, &block|
        buckets << bucket
        if bucket == "bucket1"
          raise "ERROR!"
        elsif bucket == "bucket2"
          expect(path).to eq "path2"
          expect(opts[:original_filename]).to eq "100502_CA_B3_119_ent_num2_20200315000000.pdf"
          block.call "archive_2"
        end
      end

      allow(subject).to receive(:connect_vfitrack_net).with("to_ecs/siemens_hc/docs").and_return "connect_hsh_2"
      allow(subject).to receive(:ftp_file).with "archive_2", "connect_hsh_2"

      Timecop.freeze(now) { subject.process_entries }

      # verify that only ent1 and ent2 were processed
      expect(buckets).to contain_exactly("bucket1", "bucket2")

      ent1.reload
      expect(ent1.sync_records.count).to eq 1

      ent2.reload
      expect(ent2.sync_records.count).to eq 2
      sr2 = ent2.sync_records.find { |sr| sr.trading_partner == described_class::SYNC_TRADING_PARTNER }
      expect(sr2).not_to be_nil
      expect(sr2.sent_at).to eq now

      expect(ErrorLogEntry.count).to eq 1
      expect(JSON.parse(ErrorLogEntry.first.additional_messages_json)).to eq ["entry brok1"]
    end
  end

  describe "logged_entries" do
    # Here, "synced" refers to having sync records of this class's trading partner. "Logged" actually refers to another
    # type of sync record, having the SiemensCaXmlBillingGenerator's trading partner. The presence of the second type indicates
    # that an XML file has been generated/sent for this entry.

    it "returns logged, unsynced Siemens entries" do
      ents = subject.logged_entries
      expect(ents.count).to eq 2
      expect(ents.map(&:id)).to include(ent1.id, ent2.id)
    end

    it "skips entries without log" do
      SyncRecord.destroy_all
      ents = subject.logged_entries
      expect(ents.count).to eq 0
    end

    it "skips entries that have been synced" do
      ent1.sync_records.create! trading_partner: described_class::SYNC_TRADING_PARTNER, sent_at: now, confirmed_at: now + 1.minute
      ents = subject.logged_entries
      expect(ents.count).to eq 1
      expect(ents.first.id).to eq ent2.id
    end

    it "skips entries with file logged date earlier than system date" do
      ent1.update! file_logged_date: "2020-01-4"
      ents = subject.logged_entries
      expect(ents.count).to eq 1
    end

    it "skips entries that were logged less than 12 hours ago" do
      sr = ent1.sync_records.find { |rec| rec.trading_partner == described_class::XML_SYNC_TRADING_PARTNER }
      sr.update! sent_at: now - 11.hours
      ents = subject.logged_entries
      expect(ents.count).to eq 1
    end

    it "skips entries without archive" do
      att1.update attachment_type: "foo type"
      ents = subject.logged_entries
      expect(ents.count).to eq 1
    end
  end

  describe "partner_id" do
    it "returns production ID" do
      allow(ms).to receive(:production?).and_return true
      expect(subject.partner_id).to eq "100502"
    end

    it "returns test ID" do
      allow(ms).to receive(:production?).and_return false
      expect(subject.partner_id).to eq "1005029"
    end
  end
end
