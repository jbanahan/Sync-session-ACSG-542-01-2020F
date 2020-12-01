describe OpenChain::CustomHandler::Vandegrift::VandegriftPuma7501Parser do
  let (:xml_path) { 'spec/fixtures/files/puma_7501.xml' }
  let (:xml_data) { IO.read(xml_path) }
  let (:importer) { with_customs_management_id(FactoryBot(:importer, irs_number: '123456'), "PUMA") }

  let! (:inbound_file) do
    file = InboundFile.new
    allow(subject).to receive(:inbound_file).and_return file
    file
  end

  describe "parse" do
    subject { described_class }

    let (:shipment) { described_class::CiLoadEntry.new }

    before do
      allow_any_instance_of(subject).to receive(:inbound_file).and_return inbound_file
    end

    it "parses a file and ftps the resulting xml" do
      expect_any_instance_of(subject).to receive(:process_file).with(instance_of(Nokogiri::XML::Document)).and_return [shipment]
      expect_any_instance_of(subject).to receive(:generate_and_send_invoice_xml).with([shipment])
      subject.parse(xml_data)
    end
  end

  describe 'process_file' do
    before do
      importer
    end

    it 'parses puma file and generates CMUS data elements' do
      shipment = Array.wrap(subject.process_file(Nokogiri::XML(xml_data))).first
      expect(shipment.customer).to eq("PUMA")
      expect(shipment.file_number).to eq("20200319P")

      invoice = shipment.invoices.first

      expect(invoice.file_number).to eq("20200319P")
      expect(invoice.invoice_number).to eq("5059096")
      expect(invoice.invoice_date).to eq(Date.new(2020, 3, 19))
      expect(invoice.currency).to eq("USD")

      line = invoice.invoice_lines.first

      expect(line.part_number).to eq("001")
      expect(line.country_of_origin).to eq("CN")
      expect(line.gross_weight).to eq("15")
      expect(line.hts).to eq("4202920807")
      expect(line.foreign_value).to eq("11.00")
      expect(line.quantity_1).to eq("2")
      expect(line.quantity_2).to eq("1")
      expect(line.mid).to eq("CNGOLENTDON")
      expect(line.spi).to eq("A")
      expect(line.spi2).to eq("B")
      expect(line.charges).to eq("88")
      expect(line.ftz_zone_status).to eq("P")
      expect(line.ftz_priv_status_date).to eq(Date.new(2019, 11, 21))
      expect(line.ftz_quantity).to eq("3")

      expect(line.tariff_lines.length).to eq 2

      tar_sup = line.tariff_lines[0]
      expect(tar_sup.hts).to eq("99038803")
      expect(tar_sup.gross_weight).to be_nil
      expect(tar_sup.foreign_value).to eq("55.66")
      expect(tar_sup.spi).to be_nil
      expect(tar_sup.spi2).to be_nil

      tar_prime = line.tariff_lines[1]
      expect(tar_prime.hts).to eq("4202920807")
      expect(tar_prime.gross_weight).to eq("15")
      expect(tar_prime.foreign_value).to eq("11.00")
      expect(tar_prime.spi).to eq("A")
      expect(tar_prime.spi2).to eq("B")

      expect(inbound_file).to have_identifier(:file_number, "20200319P")
    end

    it 'does not send FTZ data when FTZ status is not P' do
      xml_data.gsub!("<FTZ_STATUS>P</FTZ_STATUS>", "<FTZ_STATUS>Q</FTZ_STATUS>")

      shipment = Array.wrap(subject.process_file(Nokogiri::XML(xml_data))).first
      invoice = shipment.invoices.first
      line = invoice.invoice_lines.first
      expect(line.ftz_zone_status).to be_nil
      expect(line.ftz_priv_status_date).to be_nil
      expect(line.ftz_quantity).to be_nil
    end

    it 'does not include additional tariff line when there is no supplemental tariff' do
      xml_data.gsub!("99038803", " ")

      shipment = Array.wrap(subject.process_file(Nokogiri::XML(xml_data))).first
      invoice = shipment.invoices.first
      line = invoice.invoice_lines.first
      expect(line.tariff_lines).to be_nil
    end
  end
end