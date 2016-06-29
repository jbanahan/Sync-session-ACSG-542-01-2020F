require 'spec_helper'

describe OpenChain::CustomHandler::LumberLiquidators::LumberSapOrderXmlGenerator do
  before :each do
    described_class.stub(:ftp_file)
  end
  describe :send_order do
    it "should generate and FTP" do
      o = double('order')
      u = double('user')
      User.should_receive(:integration).and_return(u)
      xml = '<myxml></myxml>'
      tf = double('tempfile')
      tf.should_receive(:write).with(xml)
      tf.should_receive(:flush)
      Tempfile.should_receive(:open).with(['po_','.xml']).and_yield tf
      described_class.should_receive(:ftp_file)
      described_class.should_receive(:generate).with(u,o).and_return xml
      described_class.send_order(o)
    end
  end
  it "should use ApiEntityXmlizer" do
    u = double('user')
    o = double('order')
    f = double('field_list')
    x = double('xmlizer')
    OpenChain::Api::ApiEntityXmlizer.should_receive(:new).and_return(x)
    x.should_receive(:entity_to_xml).with(u,o,f).and_return 'xml'
    described_class.should_receive(:build_field_list).with(u).and_return f
    expect(described_class.generate(u,o)).to eq 'xml'

  end
end
