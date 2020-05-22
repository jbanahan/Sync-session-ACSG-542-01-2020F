describe OpenChain::CustomHandler::Vandegrift::VandegriftPuma7501Parser do
  let (:xml_path) { 'spec/fixtures/files/puma_7501.xml' }
  let (:xml_data) { IO.read(xml_path) }
  let(:xml) { Nokogiri::XML(xml_data) }
  let (:importer) { with_customs_management_id(Factory(:importer, irs_number: '123456'), "PUMA") }

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
      shipment = Array.wrap(subject.process_file(xml)).first
      expect(shipment.customer).to eq("PUMA")
      expect(shipment.file_number).to eq("20200319P")

      invoice = shipment.invoices.first

      expect(invoice.file_number).to eq("20200319P")
      expect(invoice.invoice_number).to eq("5059096")
      expect(invoice.invoice_date).to be_a(Date)
      expect(invoice.currency).to eq("USD")

      line = invoice.invoice_lines.first

      expect(line.part_number).to eq("001")
      expect(line.country_of_origin).to eq("CN")
      expect(line.gross_weight).to eq("1")
      expect(line.hts).to eq("4202920807")
      expect(line.foreign_value).to eq("11.00")
      expect(line.quantity_1).to eq("2")
      expect(line.quantity_2).to eq("1")
      expect(line.mid).to eq("CNGOLENTDON")
    end
  end
end