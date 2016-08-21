require 'spec_helper'

describe OpenChain::CustomHandler::LumberLiquidators::LumberSapOrderXmlGenerator do
  before :each do
    allow(described_class).to receive(:ftp_file)
  end
  describe :send_order do
    it "should generate and FTP" do
      o = double('order')
      u = double('user')
      expect(User).to receive(:integration).and_return(u)
      xml = '<myxml></myxml>'
      tf = double('tempfile')
      expect(tf).to receive(:write).with(xml)
      expect(tf).to receive(:flush)
      expect(Tempfile).to receive(:open).with(['po_','.xml']).and_yield tf
      expect(described_class).to receive(:ftp_file)
      expect(described_class).to receive(:generate).with(u,o).and_return xml
      described_class.send_order(o)
    end
  end
  it "should use ApiEntityXmlizer" do
    u = double('user')
    o = double('order')
    f = double('field_list')
    x = double('xmlizer')
    expect(OpenChain::Api::ApiEntityXmlizer).to receive(:new).and_return(x)
    expect(x).to receive(:entity_to_xml).with(u,o,f).and_return 'xml'
    expect(described_class).to receive(:build_field_list).with(u).and_return f
    expect(described_class.generate(u,o)).to eq 'xml'

  end
end
