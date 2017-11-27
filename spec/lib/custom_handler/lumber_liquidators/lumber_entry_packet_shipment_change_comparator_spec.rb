require 'spec_helper'

describe OpenChain::CustomHandler::LumberLiquidators::LumberEntryPacketShipmentChangeComparator do
  describe "accept?" do
    let (:snapshot) { EntitySnapshot.new }

    it "accepts shipment snapshots" do
      snapshot.recordable = Shipment.new
      expect(described_class.accept? snapshot).to eq true
    end

    it "does not accept snapshots for non-shipments" do
      snapshot.recordable = Entry.new
      expect(described_class.accept? snapshot).to eq false
    end
  end

  describe "compare", :snapshot do
    let (:shipment) { Factory(:shipment, master_bill_of_lading:'OOLU2100046990', reference: '555') }

    it "generates an entry packet when both components are present and there is no sync record" do
      entry = Factory(:entry, broker_reference:'19283746', master_bills_of_lading:'ABCD1426882,OOLU2100046990', customer_references:'333,555,666', source_system:Entry::KEWILL_SOURCE_SYSTEM)

      shipment.attachments.create! attachment_type:'ODS-Forwarder Ocean Document Set', attached_file_name:'file_ods.pdf', attached_file_size:1
      shipment.attachments.create! attachment_type:'VDS-Vendor Document Set', attached_file_name:'file_vds.pdf', attached_file_size:1
      snapshot = shipment.create_snapshot Factory(:user)
      expect(OpenChain::S3).to receive(:download_to_tempfile).twice.and_return(File.open('spec/fixtures/files/crew_returns.pdf', 'rb'))

      expect(OpenChain::GoogleDrive).to receive(:upload_file).with('US Entry Documents/Entry Packet/19283746 - LUMBER.pdf', instance_of(Tempfile))

      now = Time.zone.now
      Timecop.freeze(now) do
        subject.compare shipment.id, snapshot.bucket, snapshot.doc_path, snapshot.version
      end

      shipment.reload

      expect(shipment.sync_records.length).to eq 1
      sr = shipment.sync_records.first
      expect(sr.trading_partner).to eq 'Entry Packet'
      expect(sr.sent_at.to_i).to eq now.to_i
      expect(sr.confirmed_at.to_i).to eq (now + 1.minute).to_i

      mail = ActionMailer::Base.deliveries.pop
      expect(mail.to).to eq ['LL-US@vandegriftinc.com']
      expect(mail.subject).to eq 'Allport Entry Doc Success: OOLU2100046990 / 555 / 19283746'
      expect(mail.body).to include ERB::Util.html_escape("Docs for master bill 'OOLU2100046990' / shipment reference '555' have been transfered to entry '19283746'.")
      expect(mail.attachments.length).to eq(0)
    end

    it "generates an entry packet when both components are present and there is a sync record with no sent date" do
      entry = Factory(:entry, broker_reference:'19283746', master_bills_of_lading:'ABCD1426882,OOLU2100046990', customer_references:'333,555,666', source_system:Entry::KEWILL_SOURCE_SYSTEM)

      # sent_at value is not set intentionally.
      synco = shipment.sync_records.create! trading_partner:'Entry Packet'

      shipment.attachments.create! attachment_type:'ODS-Forwarder Ocean Document Set', attached_file_name:'file_ods.pdf', attached_file_size:1
      shipment.attachments.create! attachment_type:'VDS-Vendor Document Set', attached_file_name:'file_vds.pdf', attached_file_size:1
      snapshot = shipment.create_snapshot Factory(:user)
      expect(OpenChain::S3).to receive(:download_to_tempfile).twice.and_return(File.open('spec/fixtures/files/crew_returns.pdf', 'rb'))

      expect(OpenChain::GoogleDrive).to receive(:upload_file).with('US Entry Documents/Entry Packet/19283746 - LUMBER.pdf', instance_of(Tempfile))

      now = Time.zone.now
      Timecop.freeze(now) do
        subject.compare shipment.id, snapshot.bucket, snapshot.doc_path, snapshot.version
      end

      shipment.reload

      expect(shipment.sync_records.length).to eq 1
      sr = shipment.sync_records.first
      expect(sr).to eq(synco)
      expect(sr.trading_partner).to eq 'Entry Packet'
      expect(sr.sent_at.to_i).to eq now.to_i

      mail = ActionMailer::Base.deliveries.pop
      expect(mail.body).to include ERB::Util.html_escape("Revised docs for master bill 'OOLU2100046990' / shipment reference '555' have been transfered to entry '19283746'.")
    end

    it "generates an entry packet when both components are present and there is a sync record sent date is older than ODS date" do
      entry = Factory(:entry, broker_reference:'19283746', master_bills_of_lading:'ABCD1426882,OOLU2100046990', customer_references:'333,555,666', source_system:Entry::KEWILL_SOURCE_SYSTEM)

      synco = shipment.sync_records.create! sent_at:Time.zone.now, trading_partner:'Entry Packet'

      shipment.attachments.create! attachment_type:'ODS-Forwarder Ocean Document Set', attached_file_name:'file_ods.pdf', attached_file_size:1, attached_updated_at:synco.sent_at + 1.hour
      shipment.attachments.create! attachment_type:'VDS-Vendor Document Set', attached_file_name:'file_vds.pdf', attached_file_size:1, attached_updated_at:synco.sent_at - 1.hour
      snapshot = shipment.create_snapshot Factory(:user)
      expect(OpenChain::S3).to receive(:download_to_tempfile).twice.and_return(File.open('spec/fixtures/files/crew_returns.pdf', 'rb'))

      expect(OpenChain::GoogleDrive).to receive(:upload_file).with('US Entry Documents/Entry Packet/19283746 - LUMBER.pdf', instance_of(Tempfile))

      now = Time.zone.now
      Timecop.freeze(now) do
        subject.compare shipment.id, snapshot.bucket, snapshot.doc_path, snapshot.version
      end

      shipment.reload

      expect(shipment.sync_records.length).to eq 1
      sr = shipment.sync_records.first
      expect(sr).to eq(synco)
      expect(sr.trading_partner).to eq 'Entry Packet'
      expect(sr.sent_at.to_i).to eq now.to_i

      mail = ActionMailer::Base.deliveries.pop
      expect(mail.body).to include ERB::Util.html_escape("Revised docs for master bill 'OOLU2100046990' / shipment reference '555' have been transfered to entry '19283746'.")
    end

    it "generates an entry packet when both components are present and there is a sync record sent date is older than VDS date" do
      entry = Factory(:entry, broker_reference:'19283746', master_bills_of_lading:'ABCD1426882,OOLU2100046990', customer_references:'333,555,666', source_system:Entry::KEWILL_SOURCE_SYSTEM)

      synco = shipment.sync_records.create! sent_at:Time.zone.now, trading_partner:'Entry Packet'

      shipment.attachments.create! attachment_type:'ODS-Forwarder Ocean Document Set', attached_file_name:'file_ods.pdf', attached_file_size:1, attached_updated_at:synco.sent_at - 1.hour
      shipment.attachments.create! attachment_type:'VDS-Vendor Document Set', attached_file_name:'file_vds.pdf', attached_file_size:1, attached_updated_at:synco.sent_at + 1.hour
      snapshot = shipment.create_snapshot Factory(:user)
      expect(OpenChain::S3).to receive(:download_to_tempfile).twice.and_return(File.open('spec/fixtures/files/crew_returns.pdf', 'rb'))

      expect(OpenChain::GoogleDrive).to receive(:upload_file).with('US Entry Documents/Entry Packet/19283746 - LUMBER.pdf', instance_of(Tempfile))

      now = Time.zone.now
      Timecop.freeze(now) do
        subject.compare shipment.id, snapshot.bucket, snapshot.doc_path, snapshot.version
      end

      shipment.reload

      expect(shipment.sync_records.length).to eq 1
      sr = shipment.sync_records.first
      expect(sr).to eq(synco)
      expect(sr.trading_partner).to eq 'Entry Packet'
      expect(sr.sent_at.to_i).to eq now.to_i

      mail = ActionMailer::Base.deliveries.pop
      expect(mail.body).to include ERB::Util.html_escape("Revised docs for master bill 'OOLU2100046990' / shipment reference '555' have been transfered to entry '19283746'.")
    end

    it "does not generate an entry packet when both components are present, but the sync record date is newer than both ODS and VDS dates" do
      entry = Factory(:entry, broker_reference:'19283746', master_bills_of_lading:'ABCD1426882,OOLU2100046990', customer_references:'333,555,666', source_system:Entry::KEWILL_SOURCE_SYSTEM)

      original_sent_at = Time.zone.now - 1.hour
      synco = shipment.sync_records.create! sent_at:original_sent_at, trading_partner:'Entry Packet'

      shipment.attachments.create! attachment_type:'ODS-Forwarder Ocean Document Set', attached_file_name:'file_ods.pdf', attached_file_size:1, attached_updated_at:synco.sent_at - 1.day
      shipment.attachments.create! attachment_type:'VDS-Vendor Document Set', attached_file_name:'file_vds.pdf', attached_file_size:1, attached_updated_at:synco.sent_at - 1.day
      snapshot = shipment.create_snapshot Factory(:user)

      subject.compare shipment.id, snapshot.bucket, snapshot.doc_path, snapshot.version

      shipment.reload

      expect(shipment.sync_records.length).to eq 1
      sr = shipment.sync_records.first
      expect(sr).to eq(synco)
      expect(sr.trading_partner).to eq 'Entry Packet'
      expect(sr.sent_at.to_i).to eq original_sent_at.to_i

      expect(ActionMailer::Base.deliveries.pop).to eq(nil)
    end

    it "does not generate an entry packet when both VDS attachment not present" do
      entry = Factory(:entry, broker_reference:'19283746', master_bills_of_lading:'ABCD1426882,OOLU2100046990', customer_references:'333,555,666', source_system:Entry::KEWILL_SOURCE_SYSTEM)

      original_sent_at = Time.zone.now - 1.hour
      synco = shipment.sync_records.create! sent_at:original_sent_at, trading_partner:'Entry Packet'

      shipment.attachments.create! attachment_type:'ODS-Forwarder Ocean Document Set', attached_file_name:'file_ods.pdf', attached_file_size:1, attached_updated_at:synco.sent_at + 1.day
      snapshot = shipment.create_snapshot Factory(:user)

      subject.compare shipment.id, snapshot.bucket, snapshot.doc_path, snapshot.version

      shipment.reload

      expect(shipment.sync_records.length).to eq 1
      sr = shipment.sync_records.first
      expect(sr).to eq(synco)
      expect(sr.trading_partner).to eq 'Entry Packet'
      expect(sr.sent_at.to_i).to eq original_sent_at.to_i

      expect(ActionMailer::Base.deliveries.pop).to eq(nil)
    end

    it "does not generate an entry packet when both ODS attachment not present" do
      entry = Factory(:entry, broker_reference:'19283746', master_bills_of_lading:'ABCD1426882,OOLU2100046990', customer_references:'333,555,666', source_system:Entry::KEWILL_SOURCE_SYSTEM)

      original_sent_at = Time.zone.now - 1.hour
      synco = shipment.sync_records.create! sent_at:original_sent_at, trading_partner:'Entry Packet'

      shipment.attachments.create! attachment_type:'VDS-Vendor Document Set', attached_file_name:'file_vds.pdf', attached_file_size:1, attached_updated_at:synco.sent_at + 1.day
      snapshot = shipment.create_snapshot Factory(:user)

      subject.compare shipment.id, snapshot.bucket, snapshot.doc_path, snapshot.version

      shipment.reload

      expect(shipment.sync_records.length).to eq 1
      sr = shipment.sync_records.first
      expect(sr).to eq(synco)
      expect(sr.trading_partner).to eq 'Entry Packet'
      expect(sr.sent_at.to_i).to eq original_sent_at.to_i

      expect(ActionMailer::Base.deliveries.pop).to eq(nil)
    end

    it "handles case where entry not found" do
      shipment.attachments.create! attachment_type:'ODS-Forwarder Ocean Document Set', attached_file_name:'file_ods.pdf', attached_file_size:1
      shipment.attachments.create! attachment_type:'VDS-Vendor Document Set', attached_file_name:'file_vds.pdf', attached_file_size:1
      snapshot = shipment.create_snapshot Factory(:user)
      expect(OpenChain::S3).to receive(:download_to_tempfile).twice.and_return(File.open('spec/fixtures/files/crew_returns.pdf', 'rb'))

      now = Time.zone.now
      Timecop.freeze(now) do
        subject.compare shipment.id, snapshot.bucket, snapshot.doc_path, snapshot.version
      end

      shipment.reload

      expect(shipment.sync_records.length).to eq 1
      sr = shipment.sync_records.first
      expect(sr.trading_partner).to eq 'Entry Packet'
      expect(sr.sent_at.to_i).to eq now.to_i

      mail = ActionMailer::Base.deliveries.pop
      expect(mail.to).to eq ['LL-US@vandegriftinc.com']
      expect(mail.subject).to eq 'Allport Missing Entry: OOLU2100046990 / 555'
      expect(mail.body).to include ERB::Util.html_escape("No entry could be found for master bill 'OOLU2100046990' / shipment reference '555'.  Once the entry has been opened, the attached Entry Packet document must be attached to it.")
      expect(mail.attachments.length).to eq(1)
      expect(mail.attachments[0].filename).to eq('EntryPacket - LUMBER.pdf')
    end

  end


end