require 'spec_helper'

describe OpenChain::CustomHandler::Baillie::BaillieOrderXmlParser do

  describe '#parse' do
    it "should delegate to LaceySimplifiedOrderXmlParser" do
      data = double('data')
      opts = double('opts')
      expect(OpenChain::CustomHandler::Generic::LaceySimplifiedOrderXmlParser).to receive(:parse).with(data,opts)
      described_class.parse(data, opts)
    end
  end
  describe '#integration_folder' do
    it "should return integration folder" do
      expect(described_class.integration_folder).to eq '/home/ubuntu/ftproot/chainroot/baillie/_po_xml'
    end
  end
end
