require 'spec_helper' 
describe OpenChain::CustomHandler::EcellerateXmlRouter do
  describe "parse_file" do
    it "should call parse_dom" do
      data = "xyz"
      dom = double('dom')
      log = double('log')
      expect(REXML::Document).to receive(:new).with(data).and_return(dom)
      expect(described_class).to receive(:parse_dom).with(dom, log)
      described_class.parse_file data, log
    end
  end
  describe "parse_dom" do
    let (:log) { InboundFile.new }

    it "should route JJILL to JJILL parser" do
      dom = REXML::Document.new("<?xml version=\"1.0\" encoding=\"UTF-8\"?><ShipNotice><Parties><Party><PartyType>Importer</PartyType><PartyCode>JILSO</PartyCode></Party></Parties></ShipNotice>")
      expect(OpenChain::CustomHandler::JJill::JJillEcellerateXmlParser).to receive(:parse_dom).with(dom, log)
      described_class.parse_dom(dom, log)
    end
    it "should swallow unidentified file" do
      dom = REXML::Document.new("<?xml version=\"1.0\" encoding=\"UTF-8\"?><ShipNotice><Parties><Party><PartyType>Importer</PartyType><PartyCode>OTHER</PartyCode></Party></Parties></ShipNotice>")
      expect(OpenChain::CustomHandler::JJill::JJillEcellerateXmlParser).not_to receive(:parse_dom).with(dom, log)
      described_class.parse_dom(dom, log)
    end
  end
end