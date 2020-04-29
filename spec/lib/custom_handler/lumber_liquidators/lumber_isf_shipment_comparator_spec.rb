require "rexml/document"

describe OpenChain::CustomHandler::LumberLiquidators::LumberIsfShipmentComparator do
  describe "accept?" do
    let (:snapshot) { EntitySnapshot.new }

    it "accepts shipment snapshot with ISF sent at and without canceled date" do
      snapshot.recordable = Shipment.new(isf_sent_at:Date.new(2018, 1, 31), canceled_date:nil)
      expect(described_class.accept? snapshot).to eq true
    end

    it "does not accept shipment snapshot with canceled date" do
      snapshot.recordable = Shipment.new(isf_sent_at:Date.new(2018, 1, 31), canceled_date:Date.new(2018, 1, 31))
      expect(described_class.accept? snapshot).to eq false
    end

    it "does not accept shipment snapshot without ISF sent at" do
      snapshot.recordable = Shipment.new(isf_sent_at: nil, canceled_date:nil)
      expect(described_class.accept? snapshot).to eq false
    end

    it "does not accept snapshots for non-shipments" do
      snapshot.recordable = Entry.new
      expect(described_class.accept? snapshot).to eq false
    end
  end

  describe "compare", :snapshot do
    let(:isf_revised) {
      described_class.prep_custom_definitions([:shp_isf_revised_date])[:shp_isf_revised_date]
    }

    it "generates an ISF XML when ISF sent at changes" do
      shipment = Shipment.new(reference: '555', isf_sent_at:Date.new(2018, 1, 29))
      shipment.save!
      snapshot_old = shipment.create_snapshot Factory(:user)

      shipment.update_attributes!(isf_sent_at:Date.new(2018, 1, 31))
      snapshot_new = shipment.create_snapshot Factory(:user)

      xml = "<root_name><a>SomeValue</a><b>SomeOtherValue</b></root_name>"
      expect(OpenChain::CustomHandler::LumberLiquidators::LumberIsfShipmentXmlGenerator).to receive(:generate_xml).with(shipment).and_return(REXML::Document.new(xml))
      xml_output_file = nil
      synced = nil
      ftp_info_hash = nil
      expect(subject).to receive(:ftp_sync_file) { |file_arg, sync_arg, opt_arg|
        xml_output_file = file_arg
        synced = sync_arg
        ftp_info_hash = opt_arg
      }

      now = Time.zone.now
      Timecop.freeze(now) do
        subject.compare shipment.id, snapshot_old.bucket, snapshot_old.doc_path, snapshot_old.version, snapshot_new.bucket, snapshot_new.doc_path, snapshot_new.version
      end

      shipment.reload
      expect(shipment.sync_records.length).to eq 1
      sr = shipment.sync_records.first
      expect(sr).to eq(synced)
      expect(sr.trading_partner).to eq 'ISF'
      expect(sr.sent_at.to_i).to eq now.to_i
      expect(sr.confirmed_at.to_i).to eq (now + 1.minute).to_i

      begin
        expect(xml_output_file.original_filename).to eq("ISF_555_#{now.strftime('%Y%m%d%H%M%S')}.xml")
        xml_output_file.open
        expect(xml_output_file.read).to eq(xml)
      ensure
        xml_output_file.close! if xml_output_file && !xml_output_file.closed?
      end

      expect(ftp_info_hash[:username]).to eq('www-vfitrack-net')
      expect(ftp_info_hash[:folder]).to eq('to_ecs/lumber_isf_test')
    end

    it "generates an ISF XML when ISF revised at changes" do
      shipment = Shipment.new(reference: '555')
      shipment.save!
      shipment.update_custom_value! isf_revised, '2017-01-01'
      snapshot_old = shipment.create_snapshot Factory(:user)

      shipment.update_custom_value! isf_revised, '2018-01-01'
      snapshot_new = shipment.create_snapshot Factory(:user)

      expect(subject).to receive(:send_isf_xml).with(shipment)

      subject.compare shipment.id, snapshot_old.bucket, snapshot_old.doc_path, snapshot_old.version, snapshot_new.bucket, snapshot_new.doc_path, snapshot_new.version
    end

    it "does not generate an ISF XML when ISF sent at does not change" do
      shipment = Shipment.new(reference: '555', isf_sent_at:Date.new(2018, 1, 29))
      shipment.save!
      snapshot_old = shipment.create_snapshot Factory(:user)

      shipment.update_attributes!(isf_sent_at:Date.new(2018, 1, 29))
      snapshot_new = shipment.create_snapshot Factory(:user)

      expect(OpenChain::CustomHandler::LumberLiquidators::LumberIsfShipmentXmlGenerator).not_to receive(:generate_xml)
      expect(subject).not_to receive(:ftp_sync_file)

      subject.compare shipment.id, snapshot_old.bucket, snapshot_old.doc_path, snapshot_old.version, snapshot_new.bucket, snapshot_new.doc_path, snapshot_new.version

      shipment.reload

      expect(shipment.sync_records.length).to eq 0
    end

    it "does not generate an ISF XML when ISF revised at does not change" do
      shipment = Shipment.new(reference: '555')
      shipment.save!
      shipment.update_custom_value! isf_revised, '2017-01-01'
      snapshot_old = shipment.create_snapshot Factory(:user)
      snapshot_new = shipment.create_snapshot Factory(:user)

      expect(subject).not_to receive(:send_isf_xml).with(shipment)

      subject.compare shipment.id, snapshot_old.bucket, snapshot_old.doc_path, snapshot_old.version, snapshot_new.bucket, snapshot_new.doc_path, snapshot_new.version
    end

    it "updates existing sync record if present" do
      shipment = Shipment.new(reference: '555', isf_sent_at:Date.new(2018, 1, 29))
      shipment.save!
      snapshot_old = shipment.create_snapshot Factory(:user)

      shipment.update_attributes!(isf_sent_at:Date.new(2018, 1, 31))
      snapshot_new = shipment.create_snapshot Factory(:user)

      synco = shipment.sync_records.create! trading_partner:'ISF', sent_at:Date.new(2018, 1, 29)

      xml = "<root_name><a>SomeValue</a><b>SomeOtherValue</b></root_name>"
      expect(OpenChain::CustomHandler::LumberLiquidators::LumberIsfShipmentXmlGenerator).to receive(:generate_xml).with(shipment).and_return(REXML::Document.new(xml))
      expect(subject).to receive(:ftp_sync_file).with(instance_of(Tempfile), synco, instance_of(Hash))

      now = Time.zone.now
      Timecop.freeze(now) do
        subject.compare shipment.id, snapshot_old.bucket, snapshot_old.doc_path, snapshot_old.version, snapshot_new.bucket, snapshot_new.doc_path, snapshot_new.version
      end

      shipment.reload

      expect(shipment.sync_records.length).to eq 1
      sr = shipment.sync_records.first
      expect(sr).to eq(synco)
      expect(sr.trading_partner).to eq 'ISF'
      expect(sr.sent_at.to_i).to eq now.to_i
      expect(sr.confirmed_at.to_i).to eq (now + 1.minute).to_i
    end

    # Represents the extremely unlikely case where a shipment is deleted while this evaluation is underway.
    it "does not generate an ISF XML when the shipment can't be found" do
      shipment = Shipment.new(reference: '555', isf_sent_at:Date.new(2018, 1, 29))
      shipment.save!
      snapshot_old = shipment.create_snapshot Factory(:user)

      shipment.update_attributes!(isf_sent_at:Date.new(2018, 1, 31))
      snapshot_new = shipment.create_snapshot Factory(:user)

      shipment.delete

      expect(OpenChain::CustomHandler::LumberLiquidators::LumberIsfShipmentXmlGenerator).not_to receive(:generate_xml)
      expect(subject).not_to receive(:ftp_sync_file)

      subject.compare shipment.id, snapshot_old.bucket, snapshot_old.doc_path, snapshot_old.version, snapshot_new.bucket, snapshot_new.doc_path, snapshot_new.version
    end

    it "uses production FTP folder if instance of LL production" do
      ms = stub_master_setup
      expect(ms).to receive(:production?).and_return(true)

      shipment = Shipment.new(reference: '555', isf_sent_at:Date.new(2018, 1, 29))
      shipment.save!
      snapshot_old = shipment.create_snapshot Factory(:user)

      shipment.update_attributes!(isf_sent_at:Date.new(2018, 1, 31))
      snapshot_new = shipment.create_snapshot Factory(:user)

      xml = "<root_name><a>SomeValue</a><b>SomeOtherValue</b></root_name>"
      expect(OpenChain::CustomHandler::LumberLiquidators::LumberIsfShipmentXmlGenerator).to receive(:generate_xml).with(shipment).and_return(REXML::Document.new(xml))
      ftp_info_hash = nil
      expect(subject).to receive(:ftp_sync_file) { |file_arg, sync_arg, opt_arg|
        ftp_info_hash = opt_arg
      }

      subject.compare shipment.id, snapshot_old.bucket, snapshot_old.doc_path, snapshot_old.version, snapshot_new.bucket, snapshot_new.doc_path, snapshot_new.version

      expect(ftp_info_hash[:username]).to eq('www-vfitrack-net')
      expect(ftp_info_hash[:folder]).to eq('to_ecs/lumber_isf')
    end
  end

end