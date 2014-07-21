require 'spec_helper' 
describe OpenChain::CustomHandler::EcellerateXmlRouter do
  describe :parse do
    it "should call parse_dom" do
      data = "xyz"
      dom = double('dom')
      u = double('user')
      REXML::Document.should_receive(:new).with(data).and_return(dom)
      described_class.should_receive(:parse_dom).with(dom, u)
      described_class.parse data, u
    end
  end
  describe :parse_dom do
    it "should route JJILL to JJILL parser" do
      dom = REXML::Document.new("<?xml version=\"1.0\" encoding=\"UTF-8\"?><ShipNotice><Parties><Party><PartyType>Importer</PartyType><PartyCode>JILSO</PartyCode></Party></Parties></ShipNotice>")
      u = double('user')
      OpenChain::CustomHandler::JJill::JJillEcellerateXmlParser.should_receive(:parse_dom).with(dom,u)
      described_class.parse_dom(dom,u)
    end
    it "should swallow unidentified file" do
       dom = REXML::Document.new("<?xml version=\"1.0\" encoding=\"UTF-8\"?><ShipNotice><Parties><Party><PartyType>Importer</PartyType><PartyCode>OTHER</PartyCode></Party></Parties></ShipNotice>")
      u = double('user')
      OpenChain::CustomHandler::JJill::JJillEcellerateXmlParser.should_not_receive(:parse_dom).with(dom,u)
      described_class.parse_dom(dom,u)
    end
  end
end