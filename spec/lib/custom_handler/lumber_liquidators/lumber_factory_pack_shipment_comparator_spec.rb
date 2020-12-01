describe OpenChain::CustomHandler::LumberLiquidators::LumberFactoryPackShipmentComparator do
  let(:cdef) { described_class.prep_custom_definitions([:shp_factory_pack_revised_date])[:shp_factory_pack_revised_date] }

  describe "accept?" do
    let (:snapshot) { EntitySnapshot.new }

    it "accepts shipment snapshot withhout canceled date" do
      snapshot.recordable = Shipment.new(canceled_date:nil)
      expect(described_class.accept? snapshot).to eq true
    end

    it "does not accept shipment snapshot with canceled date" do
      snapshot.recordable = Shipment.new(canceled_date:Date.new(2018, 1, 31))
      expect(described_class.accept? snapshot).to eq false
    end

    it "does not accept snapshots for non-shipments" do
      snapshot.recordable = Entry.new
      expect(described_class.accept? snapshot).to eq false
    end
  end

  describe "compare", :snapshot do
    it "generates CSV when packing list sent at changes" do
      shipment = Shipment.new(reference: '555', packing_list_sent_date: Date.new(2018, 1, 29))
      shipment.find_and_set_custom_value(cdef, Date.new(2018, 2, 20))
      shipment.save!
      snapshot_old = shipment.create_snapshot FactoryBot(:user)

      shipment.update_attributes!(packing_list_sent_date:Date.new(2018, 1, 31))
      snapshot_new = shipment.create_snapshot FactoryBot(:user)

      csv = "A,B,C"
      expect(OpenChain::CustomHandler::LumberLiquidators::LumberFactoryBotPackCsvGenerator).to receive(:generate_csv).with(shipment).and_return(csv)
      csv_output_file = nil
      synced = nil
      ftp_info_hash = nil
      expect(subject).to receive(:ftp_sync_file) { |file_arg, sync_arg, opt_arg|
        csv_output_file = file_arg
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
      expect(sr.trading_partner).to eq 'FactoryBot Pack Declaration'
      expect(sr.sent_at.to_i).to eq now.to_i
      expect(sr.confirmed_at.to_i).to eq (now + 1.minute).to_i

      begin
        expect(csv_output_file.original_filename).to eq("FP_555_#{now.strftime('%Y%m%d%H%M%S')}.csv")
        csv_output_file.open
        expect(csv_output_file.read).to eq(csv)
      ensure
        csv_output_file.close! if csv_output_file && !csv_output_file.closed?
      end

      expect(ftp_info_hash[:username]).to eq('www-vfitrack-net')
      expect(ftp_info_hash[:folder]).to eq('to_ecs/lumber_factory_pack_test')
    end

    it "generates CSV when factory pack revised date changes" do
      shipment = Shipment.new(reference: '555', packing_list_sent_date:Date.new(2018, 1, 29))
      shipment.find_and_set_custom_value(cdef, Date.new(2018, 2, 20))
      shipment.save!
      snapshot_old = shipment.create_snapshot FactoryBot(:user)

      shipment.update_custom_value!(cdef, Date.new(2018, 2, 21))
      snapshot_new = shipment.create_snapshot FactoryBot(:user)

      csv = "A,B,C"
      expect(OpenChain::CustomHandler::LumberLiquidators::LumberFactoryBotPackCsvGenerator).to receive(:generate_csv).with(shipment).and_return(csv)
      csv_output_file = nil
      synced = nil
      ftp_info_hash = nil
      expect(subject).to receive(:ftp_sync_file) { |file_arg, sync_arg, opt_arg|
        csv_output_file = file_arg
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
      expect(sr.trading_partner).to eq 'FactoryBot Pack Declaration'
      expect(sr.sent_at.to_i).to eq now.to_i
      expect(sr.confirmed_at.to_i).to eq (now + 1.minute).to_i

      begin
        expect(csv_output_file.original_filename).to eq("FP_555_#{now.strftime('%Y%m%d%H%M%S')}.csv")
        csv_output_file.open
        expect(csv_output_file.read).to eq(csv)
      ensure
        csv_output_file.close! if csv_output_file && !csv_output_file.closed?
      end

      expect(ftp_info_hash[:username]).to eq('www-vfitrack-net')
      expect(ftp_info_hash[:folder]).to eq('to_ecs/lumber_factory_pack_test')
    end

    it "does not generate CSV when ISF sent at and factory pack revised date do not change" do
      shipment = Shipment.new(reference: '555', packing_list_sent_date:Date.new(2018, 1, 29))
      shipment.find_and_set_custom_value(cdef, Date.new(2018, 2, 20))
      shipment.save!
      snapshot_old = shipment.create_snapshot FactoryBot(:user)

      snapshot_new = shipment.create_snapshot FactoryBot(:user)

      expect(OpenChain::CustomHandler::LumberLiquidators::LumberFactoryBotPackCsvGenerator).not_to receive(:generate_csv)
      expect(subject).not_to receive(:ftp_sync_file)

      subject.compare shipment.id, snapshot_old.bucket, snapshot_old.doc_path, snapshot_old.version, snapshot_new.bucket, snapshot_new.doc_path, snapshot_new.version

      shipment.reload

      expect(shipment.sync_records.length).to eq 0
    end

    it "updates existing sync record if present" do
      shipment = Shipment.new(reference: '555', packing_list_sent_date:Date.new(2018, 1, 29))
      shipment.save!
      snapshot_old = shipment.create_snapshot FactoryBot(:user)

      shipment.update_attributes!(packing_list_sent_date:Date.new(2018, 1, 31))
      snapshot_new = shipment.create_snapshot FactoryBot(:user)

      synco = shipment.sync_records.create! trading_partner:'FactoryBot Pack Declaration', sent_at:Date.new(2018, 1, 29)

      expect(OpenChain::CustomHandler::LumberLiquidators::LumberFactoryBotPackCsvGenerator).to receive(:generate_csv).with(shipment).and_return('A,B,C')
      expect(subject).to receive(:ftp_sync_file).with(instance_of(Tempfile), synco, instance_of(Hash))

      now = Time.zone.now
      Timecop.freeze(now) do
        subject.compare shipment.id, snapshot_old.bucket, snapshot_old.doc_path, snapshot_old.version, snapshot_new.bucket, snapshot_new.doc_path, snapshot_new.version
      end

      shipment.reload

      expect(shipment.sync_records.length).to eq 1
      sr = shipment.sync_records.first
      expect(sr).to eq(synco)
      expect(sr.trading_partner).to eq 'FactoryBot Pack Declaration'
      expect(sr.sent_at.to_i).to eq now.to_i
      expect(sr.confirmed_at.to_i).to eq (now + 1.minute).to_i
    end

    # Represents the extremely unlikely case where a shipment is deleted while this evaluation is underway.
    it "does not generate CSV when the shipment can't be found" do
      shipment = Shipment.new(reference: '555', packing_list_sent_date:Date.new(2018, 1, 29))
      shipment.save!
      snapshot_old = shipment.create_snapshot FactoryBot(:user)

      shipment.update_attributes!(packing_list_sent_date:Date.new(2018, 1, 31))
      snapshot_new = shipment.create_snapshot FactoryBot(:user)

      shipment.delete

      expect(OpenChain::CustomHandler::LumberLiquidators::LumberFactoryBotPackCsvGenerator).not_to receive(:generate_csv)
      expect(subject).not_to receive(:ftp_sync_file)

      subject.compare shipment.id, snapshot_old.bucket, snapshot_old.doc_path, snapshot_old.version, snapshot_new.bucket, snapshot_new.doc_path, snapshot_new.version
    end

    it "uses production FTP folder if instance of LL production" do
      ms = stub_master_setup
      expect(ms).to receive(:production?).and_return(true)

      shipment = Shipment.new(reference: '555', packing_list_sent_date:Date.new(2018, 1, 29))
      shipment.save!
      snapshot_old = shipment.create_snapshot FactoryBot(:user)

      shipment.update_attributes!(packing_list_sent_date:Date.new(2018, 1, 31))
      snapshot_new = shipment.create_snapshot FactoryBot(:user)

      expect(OpenChain::CustomHandler::LumberLiquidators::LumberFactoryBotPackCsvGenerator).to receive(:generate_csv).with(shipment).and_return('A,B,C')
      ftp_info_hash = nil
      expect(subject).to receive(:ftp_sync_file) { |file_arg, sync_arg, opt_arg|
        ftp_info_hash = opt_arg
      }

      subject.compare shipment.id, snapshot_old.bucket, snapshot_old.doc_path, snapshot_old.version, snapshot_new.bucket, snapshot_new.doc_path, snapshot_new.version

      expect(ftp_info_hash[:username]).to eq('www-vfitrack-net')
      expect(ftp_info_hash[:folder]).to eq('to_ecs/lumber_factory_pack')
    end
  end

end