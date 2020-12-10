describe OpenChain::CustomHandler::Ferguson::FergusonEntryBillingPacketSender do

  describe "run_schedulable" do
    it "calls process_entries method" do
      sender = instance_double("sender")
      expect(described_class).to receive(:new).and_return sender
      expect(sender).to receive(:process_entries).with(no_args)

      described_class.run_schedulable
    end
  end

  describe "process_entries" do
    it "sends billing packets" do
      current = ActiveSupport::TimeZone["America/New_York"].parse("2020-03-24 02:05:08")

      Timecop.freeze(current) do
        ent_1 = Factory(:entry, entry_number: "567890", customer_number: "FERENT")
        ent_1.sync_records.create!(trading_partner: described_class::XML_SEND_SYNC_TRADING_PARTNER, sent_at: current - 241.minutes)
        sr_ent_1 = ent_1.sync_records.create!(trading_partner: described_class::SYNC_TRADING_PARTNER, sent_at: current - 1.day, confirmed_at: current - 1.day)
        sr_ent_1.set_context described_class::SEND_COUNT, "02"
        sr_ent_1.save!
        ent_1.attachments.create!(attachment_type: "Archive Packet")
        ent_1.attachments.create!(attachment_type: "Billing Invoice", created_at: current - 241.minutes)

        # Declaration XML send was not quite 4 hours ago.
        ent_too_new = Factory(:entry, entry_number: "567891", customer_number: "FERENT")
        ent_too_new.sync_records.create!(trading_partner: described_class::XML_SEND_SYNC_TRADING_PARTNER, sent_at: current - 239.minutes)
        att_too_new = ent_too_new.attachments.create!(attachment_type: "Archive Packet")
        expect(att_too_new).not_to receive(:bucket)

        ent_2 = Factory(:entry, entry_number: "567892", customer_number: "HPPRO")
        ent_2.sync_records.create!(trading_partner: described_class::XML_SEND_SYNC_TRADING_PARTNER, sent_at: current - 242.minutes)
        ent_2.attachments.create!(attachment_type: "Archive Packet")
        ent_2.attachments.create!(attachment_type: "Broker Invoice", created_at: current - 241.minutes)

        # This entry does not have an 'Archive Packet'-type attachment and should be ignored.
        ent_no_archive_packet = Factory(:entry, entry_number: "567893", customer_number: "FERENT")
        ent_no_archive_packet.sync_records.create!(trading_partner: described_class::XML_SEND_SYNC_TRADING_PARTNER, sent_at: current - 243.minutes)
        att_no_archive_packet = ent_no_archive_packet.attachments.create!(attachment_type: "Aardvark Pocket")
        expect(att_no_archive_packet).not_to receive(:bucket)

        # This entry had an archive packet sent for it at a future time: this is a goofy workaround for
        # the comparison involving updated at, which is always going to be 'current'.  This entry is meant to
        # represent a case where the entry does not 'needs_sync'.
        ent_recent_packet_send = Factory(:entry, entry_number: "567894", customer_number: "HPPRO")
        ent_recent_packet_send.sync_records.create!(trading_partner: described_class::XML_SEND_SYNC_TRADING_PARTNER, sent_at: current - 244.minutes)
        ent_recent_packet_send.sync_records.create!(trading_partner: described_class::SYNC_TRADING_PARTNER, sent_at: current + 5.minutes, confirmed_at: current + 6.minutes)
        att_recent_packet_send = ent_recent_packet_send.attachments.create!(attachment_type: "Archive Packet")
        expect(att_recent_packet_send).not_to receive(:bucket)

        ent_wrong_customer = Factory(:entry, entry_number: "567895", customer_number: "NOTFERG")
        ent_wrong_customer.sync_records.create!(trading_partner: described_class::XML_SEND_SYNC_TRADING_PARTNER, sent_at: current - 242.minutes)
        ent_wrong_customer.attachments.create!(attachment_type: "Archive Packet")

        # This entry has an invoice attachment, but it was added more recently than 4 hours.  We're excluding
        # it because that might mean that it hasn't been stitched into the Archive Packet yet.
        ent_recent_broker_invoice_attach = Factory(:entry, entry_number: "567896", customer_number: "FERENT")
        ent_recent_broker_invoice_attach.sync_records.create!(trading_partner: described_class::XML_SEND_SYNC_TRADING_PARTNER, sent_at: current - 242.minutes)
        ent_recent_broker_invoice_attach.attachments.create!(attachment_type: "Archive Packet")
        ent_recent_broker_invoice_attach.attachments.create!(attachment_type: "Broker Invoice", created_at: current - 239.minutes)

        # This entry has no broker invoice or billing invoice-type attachments.  It should be excluded.
        ent_no_invoice_attachment = Factory(:entry, entry_number: "567897", customer_number: "FERENT")
        ent_no_invoice_attachment.sync_records.create!(trading_partner: described_class::XML_SEND_SYNC_TRADING_PARTNER, sent_at: current - 242.minutes)
        ent_no_invoice_attachment.attachments.create!(attachment_type: "Archive Packet")

        allow_any_instance_of(Attachment).to receive(:bucket).and_return("the_bucket")
        allow_any_instance_of(Attachment).to receive(:path).and_return("the_path")

        archive_packet_1 = instance_double("archive packet 1")
        expect(OpenChain::S3).to receive(:download_to_tempfile)
          .with("the_bucket", "the_path", {original_filename: "DBS_1180119_567890_20200324020508_CBP_03.pdf"})
          .and_yield archive_packet_1
        sr_1 = nil
        expect(subject).to receive(:ftp_sync_file) do |arc, sync|
          expect(arc).to eq archive_packet_1
          expect(sync.syncable_id).to eq ent_1.id
          expect(sync.trading_partner).to eq described_class::SYNC_TRADING_PARTNER
          sr_1 = sync
        end

        archive_packet_2 = instance_double("archive packet 2")
        expect(OpenChain::S3).to receive(:download_to_tempfile)
          .with("the_bucket", "the_path", {original_filename: "DBS_1180119_567892_20200324020508_CBP_01.pdf"})
          .and_yield archive_packet_2
        sr_2 = nil
        expect(subject).to receive(:ftp_sync_file) do |arc, sync|
          expect(arc).to eq archive_packet_2
          expect(sync.syncable_id).to eq ent_2.id
          expect(sync.trading_partner).to eq described_class::SYNC_TRADING_PARTNER
          sr_2 = sync
        end

        subject.process_entries

        expect(ent_1.sync_records.find { |sr| sr.id = sr_1.id }).not_to be_nil
        expect(sr_1.sent_at).to eq ActiveSupport::TimeZone["America/New_York"].parse("2020-03-24 02:05:07")
        expect(sr_1.confirmed_at).to eq ActiveSupport::TimeZone["America/New_York"].parse("2020-03-24 02:05:08")
        expect(sr_1.context[described_class::SEND_COUNT]).to eq "03"

        expect(ent_2.sync_records.find { |sr| sr.id = sr_2.id }).not_to be_nil
        expect(sr_2.sent_at).to eq ActiveSupport::TimeZone["America/New_York"].parse("2020-03-24 02:05:07")
        expect(sr_2.confirmed_at).to eq ActiveSupport::TimeZone["America/New_York"].parse("2020-03-24 02:05:08")
        expect(sr_2.context[described_class::SEND_COUNT]).to eq "01"
      end
    end

    it "handles standard error" do
      current = ActiveSupport::TimeZone["America/New_York"].parse("2020-03-24 02:05:08")

      Timecop.freeze(current) do
        ent_1 = Factory(:entry, entry_number: "567890", customer_number: "FERENT", broker_reference: "6838")
        ent_1.sync_records.create!(trading_partner: described_class::XML_SEND_SYNC_TRADING_PARTNER, sent_at: current - 241.minutes)
        ent_1.attachments.create!(attachment_type: "Archive Packet")
        ent_1.attachments.create!(attachment_type: "Billing Invoice", created_at: current - 241.minutes)

        ent_2 = Factory(:entry, entry_number: "567892", customer_number: "HPPRO", broker_reference: "6839")
        ent_2.sync_records.create!(trading_partner: described_class::XML_SEND_SYNC_TRADING_PARTNER, sent_at: current - 242.minutes)
        ent_2.attachments.create!(attachment_type: "Archive Packet")
        ent_2.attachments.create!(attachment_type: "Billing Invoice", created_at: current - 241.minutes)

        allow_any_instance_of(Attachment).to receive(:bucket).and_return("the_bucket")
        allow_any_instance_of(Attachment).to receive(:path).and_return("the_path")

        # Entry 1's download_to_tempfile should error out.
        err = StandardError.new("Heinous error")
        expect(OpenChain::S3).to receive(:download_to_tempfile)
          .with("the_bucket", "the_path", {original_filename: "DBS_1180119_567890_20200324020508_CBP_01.pdf"})
          .and_raise err
        expect(err).to receive(:log_me).with("entry 6838")

        # Entry 2 should work fine, even though the first entry died.
        archive_packet_2 = instance_double("archive packet 2")
        expect(OpenChain::S3).to receive(:download_to_tempfile)
          .with("the_bucket", "the_path", {original_filename: "DBS_1180119_567892_20200324020508_CBP_01.pdf"})
          .and_yield archive_packet_2
        sr_2 = nil
        expect(subject).to receive(:ftp_sync_file) do |arc, sync|
          expect(arc).to eq archive_packet_2
          expect(sync.syncable_id).to eq ent_2.id
          expect(sync.trading_partner).to eq described_class::SYNC_TRADING_PARTNER
          sr_2 = sync
        end

        subject.process_entries

        expect(ent_2.sync_records.find { |sr| sr.id = sr_2.id }).not_to be_nil
        expect(sr_2.sent_at).to eq ActiveSupport::TimeZone["America/New_York"].parse("2020-03-24 02:05:07")
        expect(sr_2.confirmed_at).to eq ActiveSupport::TimeZone["America/New_York"].parse("2020-03-24 02:05:08")
      end
    end
  end

  describe "ftp_credentials" do
    it "gets test creds" do
      allow(stub_master_setup).to receive(:production?).and_return false
      cred = subject.ftp_credentials
      expect(cred[:folder]).to eq "to_ecs/ferguson_billing_packet_test"
    end

    it "gets production creds" do
      allow(stub_master_setup).to receive(:production?).and_return true
      cred = subject.ftp_credentials
      expect(cred[:folder]).to eq "to_ecs/ferguson_billing_packet"
    end
  end

end