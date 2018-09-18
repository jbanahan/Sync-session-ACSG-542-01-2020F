describe OpenChain::CustomHandler::KewillExportShipmentParser do

  let(:log) { InboundFile.new }

  context "ocean file" do
    describe "parse_file" do
      before :each do
        @nexeo = Factory(:importer, name: "Nexeo", alliance_customer_number: "NEXEO")
      end

      it "parses an escape delimited file into a shipment" do
        subject.parse_file IO.read("spec/fixtures/files/Kewill Export Ocean File.DAT"), log

        s = Shipment.where(reference: "EXPORT-1402240").first
        expect(s).not_to be_nil

        expect(s.last_exported_from_source).to eq ActiveSupport::TimeZone["America/New_York"].parse("20151106145501")
        expect(s.importer).to eq @nexeo
        expect(s.mode).to eq "Ocean - FCL"
        expect(s.lcl).to be_falsey
        expect(s.master_bill_of_lading).to eq "2565659800"
        expect(s.gross_weight).to eq BigDecimal("19813.12")
        expect(s.importer_reference).to eq "6239191"
        expect(s.containers.first.container_number).to eq "OOLU8765987"
        expect(s.containers.first.seal_number).to eq "7127370"
        expect(s.comments.find {|c| c.subject == "Final Destination"}.body).to eq "Singapore"
        expect(s.comments.find {|c| c.subject == "Discharge Port"}.body).to eq "Kao Hsiung"
        expect(s.freight_total).to eq BigDecimal("1100.0")
        expect(s.invoice_total).to eq BigDecimal("2468.34")
        address = s.buyer_address
        expect(address).not_to be_nil
        expect(address.name).to eq "SANWA PLASTIC INDUSTRY PTE LTD"
        expect(address.line_1).to eq "28 WOODLANDS LOOP"
        expect(address.line_2).to be_nil
        expect(address.line_3).to eq "SINGAPORE   SG"
        expect(address.company).to eq @nexeo

        expect(s.shipment_lines.length).to eq 1
        l = s.shipment_lines.first
        expect(l.container).to eq s.containers.first
        expect(l.product).not_to be_nil
        expect(l.product.unique_identifier).to eq "NEXEO-POLYPROPYLENE"
        expect(l.product.importer).to eq @nexeo
        expect(l.product.custom_values.first.value).to eq "POLYPROPYLENE"
        expect(l.piece_sets.first).not_to be_nil
        expect(l.gross_kgs).to eq BigDecimal("19813")

        ol = l.piece_sets.first.order_line
        expect(ol).not_to be_nil
        expect(ol.product).to eq l.product
        expect(ol.hts).to eq "3902100000"

        expect(ol.order.importer).to eq @nexeo
        expect(ol.order.order_number).to eq "NEXEO-6966648"
        expect(ol.order.customer_order_number).to eq "6966648"

        expect(s.entity_snapshots.size).to eq 1

        expect(log.company).to eq @nexeo
        expect(log.get_identifiers(InboundFileIdentifier::TYPE_SHIPMENT_NUMBER)[0].value).to eq "1402240"
        expect(log.get_identifiers(InboundFileIdentifier::TYPE_SHIPMENT_NUMBER)[0].module_type).to eq "Shipment"
        expect(log.get_identifiers(InboundFileIdentifier::TYPE_SHIPMENT_NUMBER)[0].module_id).to eq s.id
      end

      it "reuses existing products, orders, containers and clears existing shipment lines" do
         s = Shipment.create! reference: "EXPORT-1402240"
         container = s.containers.create! container_number: "OOLU8765987"
         product = Product.create! importer: @nexeo, unique_identifier: "NEXEO-POLYPROPYLENE"
         order = Order.create! importer: @nexeo, order_number: "NEXEO-6966648"
         order_line = order.order_lines.create! product: product

         shipment_line = s.shipment_lines.create! product: product

         subject.parse_file IO.read("spec/fixtures/files/Kewill Export Ocean File.DAT"), log

         s.reload

         expect(s.shipment_lines.length).to eq 1
         expect(s.shipment_lines.first).not_to eq shipment_line
         expect(s.shipment_lines.first.line_number).to eq 1
         expect(s.shipment_lines.first.product).to eq product
         expect(s.shipment_lines.first.piece_sets.first.order_line).to eq order_line
         expect(s.containers.first).to eq container
      end

      it "reuses existing comments w/ same subjects" do
        s = Shipment.create! reference: "EXPORT-1402240"
        user = Factory(:user)

        final_dest = s.comments.create! subject: "Final Destination", body: "", user: user
        dis_port = s.comments.create! subject: "Discharge Port", body: "", user: user

        subject.parse_file IO.read("spec/fixtures/files/Kewill Export Ocean File.DAT"), log

        s.reload
        expect(s.comments.find {|c| c.subject == "Final Destination"}).to eq final_dest
        expect(s.comments.find {|c| c.subject == "Final Destination"}.body).to eq "Singapore"
        expect(s.comments.find {|c| c.subject == "Discharge Port"}).to eq dis_port
        expect(s.comments.find {|c| c.subject == "Discharge Port"}.body).to eq "Kao Hsiung"
      end

      it "parses an lcl shipment" do
        # If the underlying file data, this test will fail without adjustments to the location of the LCL/FCL flag
        data = IO.read("spec/fixtures/files/Kewill Export Ocean File.DAT")
        data[50] = "L"

        subject.parse_file data, log

        s = Shipment.where(reference: "EXPORT-1402240").first
        expect(s).not_to be_nil
        expect(s.mode).to eq "Ocean - LCL"
        expect(s.lcl).to be_truthy
      end

      it "errors if importer cannot be found" do
        @nexeo.destroy

        expect{subject.parse_file IO.read("spec/fixtures/files/Kewill Export Ocean File.DAT"), log}.to raise_error "No Importer record found with Alliance customer number of NEXEO."
        expect(log.get_messages_by_status(InboundFileMessage::MESSAGE_STATUS_REJECT)[0].message).to eq "No Importer record found with Alliance customer number of NEXEO."
      end
    end
  end

  context "ocean job" do
    before :each do
      @nexeo = Factory(:importer, name: "Nexeo", alliance_customer_number: "NEXEO")
      @lading_port = Factory(:port, schedule_d_code: "2704")
      @unlading_port = Factory(:port, schedule_k_code: "58309")
    end

    it "parses an escape delimited file into a shipment" do
      subject.parse_file IO.read("spec/fixtures/files/Kewill Export Ocean Job.DAT"), log
      s = Shipment.where(reference: "EXPORT-1402240").first
      expect(s).not_to be_nil

      expect(s.last_exported_from_source).to eq ActiveSupport::TimeZone["America/New_York"].parse("20151106145503")
      expect(s.vessel_carrier_scac).to eq "OOLU"
      expect(s.lading_port).to eq @lading_port
      expect(s.unlading_port).to eq @unlading_port
      expect(s.house_bill_of_lading).to eq "3401470"
      expect(s.booking_carrier).to eq "OOLU"
      expect(s.voyage).to eq "092W"
      expect(s.vessel).to eq "OOCL LONG BEACH"
      expect(s.est_departure_date).to eq Date.new(2015,11,2)
      expect(s.est_arrival_port_date).to eq Date.new(2015,12,13)
      expect(s.entity_snapshots.size).to eq 1

      expect(log.company).to be_nil
      expect(log.get_identifiers(InboundFileIdentifier::TYPE_SHIPMENT_NUMBER)[0].value).to eq "1402240"
      expect(log.get_identifiers(InboundFileIdentifier::TYPE_SHIPMENT_NUMBER)[0].module_type).to eq "Shipment"
      expect(log.get_identifiers(InboundFileIdentifier::TYPE_SHIPMENT_NUMBER)[0].module_id).to eq s.id
    end
  end
  
end