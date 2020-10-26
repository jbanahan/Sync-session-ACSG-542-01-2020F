describe OpenChain::CustomHandler::Vandegrift::MaerskCargowiseBillingParserBroker do

  subject { described_class }

  describe "preprocess_data" do
    let (:xml_data) { IO.read 'spec/fixtures/files/cargowise_freight_billing_ar_file.xml'}

    it "returns Nokogiri document" do
      expect(subject.pre_process_data(xml_data)).to be_a Nokogiri::XML::Document
    end
  end

  describe "create_parser" do

    let (:freight_data) { IO.read 'spec/fixtures/files/cargowise_freight_billing_ar_file.xml'}
    let (:brokerage_data) { IO.read 'spec/fixtures/files/maersk_broker_invoice.xml'}

    def xml_document xml_str
      doc = Nokogiri::XML xml_str
      doc.remove_namespaces!
      doc
    end

    it "returns Freight billing parser for freight files" do
      expect(subject.create_parser(nil, nil, xml_document(freight_data), nil).class).to eq OpenChain::CustomHandler::Intacct::IntacctCargowiseFreightBillingFileParser
    end

    it "returns Broker invoice parser for brokerage files" do
      expect(subject.create_parser(nil, nil, xml_document(brokerage_data), nil).class).to eq OpenChain::CustomHandler::Vandegrift::MaerskCargowiseBrokerInvoiceFileParser
    end
  end

end