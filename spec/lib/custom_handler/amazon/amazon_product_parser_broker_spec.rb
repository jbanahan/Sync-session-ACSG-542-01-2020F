describe OpenChain::CustomHandler::Amazon::AmazonProductParserBroker do

  subject { described_class }
  let! (:inbound_file) {
    f = InboundFile.new
    allow(subject).to receive(:inbound_file).and_return f
    f
  }

  describe "create_parser" do
    it "identifies standard parts files" do
      expect(subject.create_parser nil, "/path/to/US_COMPLIANCE_A2UCU5QTD5G4BE_11132019.csv", nil, nil).to eq OpenChain::CustomHandler::Amazon::AmazonProductParser
    end

    it "identifiers FDA FDG files" do
      expect(subject.create_parser nil, "/path/to/US_PGA_FDG_11132019.csv", nil, nil).to eq OpenChain::CustomHandler::Amazon::AmazonFdaProductParser
    end

    it "identifiers FDA FCT files" do
      expect(subject.create_parser nil, "/path/to/US_PGA_FCT_11132019.csv", nil, nil).to eq OpenChain::CustomHandler::Amazon::AmazonFdaProductParser
    end

    it "identifies OGA parts files" do
      # For now, since these parsers aren't written, this should error
      expect { subject.create_parser nil, "/path/to/US_PGA_BLA_A2UCU5QTD5G4BE_11132019.csv", nil, nil }.to raise_error "No parser exists to handle Amazon BLA OGA file types."
    end

    it "identifies Document files" do
      expect(subject.create_parser nil, "/path/to/US_12345789_EE908U_Ion#Enterprises_PGA_RAD_RadiationCertificate.pdf", nil, nil).to eq OpenChain::CustomHandler::Amazon::AmazonProductDocumentsParser
    end

    it "identifies FDA RAD parts files" do
      expect(subject.create_parser nil, "/path/to/US_PGA_RAD_11132019.csv", nil, nil).to eq OpenChain::CustomHandler::Amazon::AmazonFdaRadProductParser
    end

    it "identifies CVD parts files" do
      expect(subject.create_parser nil, "/path/to/US_PGA_CVD_11132019.csv", nil, nil).to eq OpenChain::CustomHandler::Amazon::AmazonCvdAddProductParser
    end

    it "identifies ADD parts files" do
      expect(subject.create_parser nil, "/path/to/US_PGA_ADD_11132019.csv", nil, nil).to eq OpenChain::CustomHandler::Amazon::AmazonCvdAddProductParser
    end

    it "identifies Lacey parts files" do
      expect(subject.create_parser nil, "/path/to/US_PGA_ALG_11132019.csv", nil, nil).to eq OpenChain::CustomHandler::Amazon::AmazonLaceyProductParser
    end

    it "errors on unexpected files" do
      expect { subject.create_parser nil, "/path/to/file.txt", nil, nil }.to raise_error "No parser exists to handle Amazon files named like 'file.txt'."
    end
  end

  describe "parse" do

    let (:opts) { {bucket: "bucket", key: "/path/to/file.csv"} }

    it "gets parser from opts key and runs data through parser" do
      expect(subject).to receive(:create_parser).with("bucket", "/path/to/file.csv", "data", opts).and_return OpenChain::CustomHandler::Amazon::AmazonProductParser
      expect(OpenChain::CustomHandler::Amazon::AmazonProductParser).to receive(:parse).with("data", opts)

      subject.parse "data", opts

      expect(inbound_file.parser_name).to eq "OpenChain::CustomHandler::Amazon::AmazonProductParser"
    end
  end
end