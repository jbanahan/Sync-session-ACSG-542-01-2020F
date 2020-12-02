require "rexml/document"
describe OpenChain::CustomHandler::LumberLiquidators::LumberBookingRequestShipmentComparator do
  describe "accept?" do
    let (:snapshot) { EntitySnapshot.new }

    it "accepts shipment snapshot with booking received date and without canceled date" do
      snapshot.recordable = Shipment.new(booking_received_date:Date.new(2018, 6, 30), canceled_date:nil)
      expect(described_class.accept? snapshot).to eq true
    end

    it "does not accept shipment snapshot with canceled date" do
      snapshot.recordable = Shipment.new(booking_received_date:Date.new(2018, 6, 30), canceled_date:Date.new(2018, 1, 31))
      expect(described_class.accept? snapshot).to eq false
    end

    it "does not accept shipment snapshot without booking received date" do
      snapshot.recordable = Shipment.new(booking_received_date: nil, canceled_date:nil)
      expect(described_class.accept? snapshot).to eq false
    end

    it "does not accept snapshots for non-shipments" do
      snapshot.recordable = Entry.new
      expect(described_class.accept? snapshot).to eq false
    end

    it "ignores snapshots with booking received dates prior to June 1, 2018" do
      snapshot.recordable = Shipment.new(booking_received_date:Date.new(2018, 5, 31), canceled_date:Date.new(2018, 1, 31))
      expect(described_class.accept? snapshot).to eq false
    end
  end

  describe "compare" do
    it "generates a booking request when booking received date is set and booking hasn't been sent" do
      shipment = Shipment.new(reference: '555', booking_received_date:Date.new(2018, 6, 2))
      shipment.save!

      xml = "<root_name><a>SomeValue</a><b>SomeOtherValue</b></root_name>"
      expect(OpenChain::CustomHandler::LumberLiquidators::LumberBookingRequestXmlGenerator).to receive(:generate_xml).with(shipment).and_return(REXML::Document.new(xml))
      xml_output_file = nil
      synced = nil
      ftp_info_hash = nil
      expect(subject).to receive(:ftp_sync_file) { |file_arg, sync_arg, opt_arg|
        xml_output_file = file_arg
        synced = sync_arg
        ftp_info_hash = opt_arg
      }
      now = Time.zone.now
      Timecop.freeze { subject.compare shipment.id }

      shipment.reload
      expect(shipment.sync_records.length).to eq 1
      sr = shipment.sync_records.first
      expect(sr).to eq(synced)
      expect(sr.trading_partner).to eq 'Booking Request'
      expect(sr.sent_at.to_i).to eq now.to_i
      expect(sr.confirmed_at.to_i).to eq (now + 1.minute).to_i

      begin
        expect(xml_output_file.original_filename).to eq("BR_555_#{now.strftime('%Y%m%d%H%M%S')}.xml")
        xml_output_file.open
        expect(xml_output_file.read).to eq(xml)
      ensure
        xml_output_file.close! if xml_output_file && !xml_output_file.closed?
      end

      expect(ftp_info_hash[:username]).to eq('www-vfitrack-net')
      expect(ftp_info_hash[:folder]).to eq('to_ecs/lumber_booking_request_test')
    end

    it "does not generate a booking request when the request has already been sent" do
      shipment = Shipment.new(reference: '555', booking_received_date:Date.new(2018, 1, 29))
      shipment.save!
      shipment.sync_records.create! trading_partner: 'Booking Request', sent_at: Time.zone.now
      shipment.update_attributes!(booking_received_date:Date.new(2018, 1, 29))
      snapshot_new = shipment.create_snapshot create(:user)

      expect(OpenChain::CustomHandler::LumberLiquidators::LumberBookingRequestXmlGenerator).not_to receive(:generate_xml)
      expect(subject).not_to receive(:ftp_sync_file)

      subject.compare shipment.id
    end

    it "does not send an updated booking request if booking received date changes" do
      shipment = Shipment.new(reference: '555', booking_received_date: Time.zone.now)
      shipment.save!

      sent_at = (Time.zone.now - 1.minute)
      synco = shipment.sync_records.create! trading_partner:'Booking Request', sent_at: sent_at

      xml = "<root_name><a>SomeValue</a><b>SomeOtherValue</b></root_name>"
      expect(OpenChain::CustomHandler::LumberLiquidators::LumberBookingRequestXmlGenerator).not_to receive(:generate_xml)
      expect(subject).not_to receive(:ftp_sync_file)

      now = Time.zone.now
      Timecop.freeze { subject.compare shipment.id }

      shipment.reload

      expect(shipment.sync_records.length).to eq 1
      sr = shipment.sync_records.first
      expect(sr).to eq(synco)
      expect(sr.trading_partner).to eq 'Booking Request'
      expect(sr.sent_at.to_i).to eq sent_at.to_i
    end

    # Represents the extremely unlikely case where a shipment is deleted while this evaluation is underway.
    it "does not generate a booking request when the shipment can't be found" do
      expect(OpenChain::CustomHandler::LumberLiquidators::LumberBookingRequestXmlGenerator).not_to receive(:generate_xml)
      expect(subject).not_to receive(:ftp_sync_file)

      subject.compare -1
    end

    it "uses production FTP folder if instance of LL production" do
      ms = stub_master_setup
      expect(ms).to receive(:production?).and_return(true)

      shipment = Shipment.new(reference: '555', booking_received_date:Date.new(2018, 6, 29))
      shipment.save!

      xml = "<root_name><a>SomeValue</a><b>SomeOtherValue</b></root_name>"
      expect(OpenChain::CustomHandler::LumberLiquidators::LumberBookingRequestXmlGenerator).to receive(:generate_xml).with(shipment).and_return(REXML::Document.new(xml))
      ftp_info_hash = nil
      expect(subject).to receive(:ftp_sync_file) { |file_arg, sync_arg, opt_arg|
        ftp_info_hash = opt_arg
      }

      subject.compare shipment.id

      expect(ftp_info_hash[:username]).to eq('www-vfitrack-net')
      expect(ftp_info_hash[:folder]).to eq('to_ecs/lumber_booking_request')
    end
  end

end