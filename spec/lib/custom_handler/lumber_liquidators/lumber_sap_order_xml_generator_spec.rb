require 'spec_helper'

describe OpenChain::CustomHandler::LumberLiquidators::LumberSapOrderXmlGenerator do
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
