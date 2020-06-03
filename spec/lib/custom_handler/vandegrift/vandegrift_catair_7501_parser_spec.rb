describe OpenChain::CustomHandler::Vandegrift::VandegriftCatair7501Parser do

  let (:data) { IO.read 'spec/fixtures/files/catair_7501.txt' }
  let! (:inbound_file) {
    file = InboundFile.new
    allow(subject).to receive(:inbound_file).and_return file
    file
  }

  let (:importer) {
    with_customs_management_id(Factory(:importer, irs_number: "30-0641353"), "CUSTNO")
  }

  describe "process_file" do
    before(:each) do
      importer
    end

    it "parses catair file and generates CMUS data elements" do
      shipment = Array.wrap(subject.process_file data).first

      expect(shipment.entry_filer_code).to be_nil
      expect(shipment.entry_number).to be_nil
      expect(shipment.file_number).to be_nil
      expect(shipment.entry_port).to eq 4103
      expect(shipment.entry_type).to eq "06"
      expect(shipment.customs_ship_mode).to eq 10
      expect(shipment.edi_identifier&.master_bill).to eq "31600000019"
      expect(shipment.customer).to eq "CUSTNO"
      expect(shipment.consignee_code).to eq "CUSTNO"
      expect(shipment.vessel).to eq "138030"
      expect(shipment.destination_state).to eq "OH"

      expect(shipment.carrier).to eq "SCAC"
      expect(shipment.unlading_port).to eq 4103
      expect(shipment.dates.first&.code).to eq :est_arrival_date
      expect(shipment.dates.first&.date).to eq Date.new(2020, 1, 13)
      expect(shipment.firms_code).to eq "HAW9"
      expect(shipment.voyage).to eq "12345"
      expect(shipment.bond_type).to eq "4"
      expect(shipment.dates.length).to eq 1

      invoice = shipment.invoices.first
      expect(invoice).not_to be_nil

      expect(invoice.invoice_number).to eq "316-0000001-9"
      expect(invoice.invoice_date).to eq Date.new(2020, 1, 13)

      line = invoice.invoice_lines.first
      expect(line).not_to be_nil
      expect(line.part_number).to eq "032"
      expect(line.spi2).to eq "X"
      expect(line.country_of_origin).to eq "CN"
      expect(line.country_of_export).to eq "VN"
      expect(line.exported_date).to eq Date.new(2000, 1, 1)
      expect(line.visa_date).to eq Date.new(2010, 1, 1)
      expect(line.spi).to eq "SP"
      expect(line.charges).to eq 1
      expect(line.lading_port).to eq 54321
      expect(line.gross_weight).to eq 1
      expect(line.textile_category_code).to eq 321
      expect(line.related_parties).to eq true
      expect(line.ftz_zone_status).to eq "P"
      expect(line.ftz_priv_status_date).to eq Date.new(2019, 12, 29)
      expect(line.ftz_quantity).to eq 1
      expect(line.ftz_expired_hts_number).to eq "9999999999"
      expect(line.visa_number).to eq "19CN1234"
      expect(line.ruling_type).to eq "R"
      expect(line.ruling_number).to eq "456789"
      expect(line.description).to eq "DESCRIPTION 1 DESCRIPTION 2"
      expect(line.mid).to eq "CNWAHLAIHUI"
      expect(line.buyer_customer_number).to eq "CUSTNO"

      expect(line.tariff_lines.length).to eq 2
      tariff = line.tariff_lines.first

      expect(tariff.hts).to eq "6404199060"
      expect(tariff.foreign_value).to eq 22
      expect(tariff.quantity_1).to eq BigDecimal(1)
      expect(tariff.uom_1).to eq "PRS"
      expect(tariff.quantity_2).to eq BigDecimal("10.50")
      expect(tariff.uom_2).to eq "KGS"
      expect(tariff.quantity_3).to eq BigDecimal("100.75")
      expect(tariff.uom_3).to eq "LBS"

      tariff = line.tariff_lines.second

      expect(tariff.hts).to eq "99038815"
      expect(tariff.foreign_value).to be_nil
      expect(tariff.quantity_1).to eq 1
      expect(tariff.uom_1).to be_blank
      expect(tariff.quantity_2).to be_nil
      expect(tariff.uom_2).to be_blank
      expect(tariff.quantity_3).to be_nil
      expect(tariff.uom_3).to be_blank
    end
  end

  describe "parse" do
    subject { described_class }
    let (:shipment) { described_class::CiLoadEntry.new }

    before :each do
      allow_any_instance_of(subject).to receive(:inbound_file).and_return inbound_file
    end

    it "parses a file and ftps the resulting xml" do
      expect_any_instance_of(subject).to receive(:process_file).with(data).and_return [shipment]
      expect_any_instance_of(subject).to receive(:generate_and_send_shipment_xml).with([shipment])
      expect_any_instance_of(subject).to receive(:send_email_notification).with([shipment], "7501")
      subject.parse data
    end
  end
end