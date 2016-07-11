require 'spec_helper'

describe OpenChain::OfficialTariffProcessor::TariffProcessorRegistry do
  it "should get EU processor for 'IT'" do
    expect(described_class.get('IT')).to be OpenChain::OfficialTariffProcessor::EuProcessor
  end
  it "should get EU processor for italy country" do
    c = Country.new
    c.iso_code = 'IT'
    expect(described_class.get(c)).to be OpenChain::OfficialTariffProcessor::EuProcessor
  end
end
