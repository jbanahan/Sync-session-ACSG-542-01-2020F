describe OpenChain::CustomHandler::Amazon::AmazonProductParserBroker do

  subject { described_class }
  let! (:inbound_file) { 
    f = InboundFile.new
    allow(subject).to receive(:inbound_file).and_return f
    f
  }

  describe "get_parser" do
    it "identifies standard parts files" do
      expect(subject.get_parser "/path/to/US_COMPLIANCE_A2UCU5QTD5G4BE_11132019.csv").to eq OpenChain::CustomHandler::Amazon::AmazonProductParser
    end

    it "identifiers FDA FDG files" do
      expect(subject.get_parser "/path/to/US_PGA_FDG_11132019.csv").to eq OpenChain::CustomHandler::Amazon::AmazonFdaProductParser
    end

    it "identifiers FDA FCT files" do
      expect(subject.get_parser "/path/to/US_PGA_FCT_11132019.csv").to eq OpenChain::CustomHandler::Amazon::AmazonFdaProductParser
    end

    it "identifies OGA parts files" do
      # For now, since these parsers aren't written, this should error
      expect { subject.get_parser "/path/to/US_PGA_RAD_A2UCU5QTD5G4BE_11132019.csv" }.to raise_error "No parser exists to handle Amazon RAD OGA file types."
    end

    it "identifies Document files" do
      expect(subject.get_parser "/path/to/US_12345789_EE908U_Ion#Enterprises_PGA_RAD_RadiationCertificate.pdf").to eq OpenChain::CustomHandler::Amazon::AmazonProductDocumentsParser
    end

    it "errors on unexpected files" do
      expect { subject.get_parser "/path/to/file.txt" }.to raise_error "No parser exists to handle Amazon files named like 'file.txt'."
    end
  end

  describe "parse" do

    let (:opts) { {key: "/path/to/file.csv"} }

    it "gets parser from opts key and runs data through parser" do
      expect(subject).to receive(:get_parser).with("/path/to/file.csv").and_return OpenChain::CustomHandler::Amazon::AmazonProductParser
      expect(OpenChain::CustomHandler::Amazon::AmazonProductParser).to receive(:parse).with("data", opts)

      subject.parse "data", opts

      expect(inbound_file.parser_name).to eq "OpenChain::CustomHandler::Amazon::AmazonProductParser"
    end
  end
end