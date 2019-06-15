describe OpenChain::CustomHandler::Baillie::BaillieOrderXmlParser do

  describe '#parse_file' do
    it "should delegate to LaceySimplifiedOrderXmlParser" do
      log = InboundFile.new
      data = double('data')
      opts = double('opts')
      expect(OpenChain::CustomHandler::Generic::LaceySimplifiedOrderXmlParser).to receive(:parse_file).with(data, log, opts)
      described_class.parse_file(data, log, opts)
    end
  end
  describe '#integration_folder' do
    it "should return integration folder" do
      expect(described_class.integration_folder).to eq ['baillie/_po_xml', '/home/ubuntu/ftproot/chainroot/baillie/_po_xml']
    end
  end
end
