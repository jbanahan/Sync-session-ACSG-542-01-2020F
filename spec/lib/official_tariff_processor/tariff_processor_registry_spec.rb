require 'spec_helper'

describe OpenChain::OfficialTariffProcessor::TariffProcessorRegistry do
  describe "get" do
    ['IT', 'GB', 'FR', 'US', 'CA'].each do |iso|
      it "gets generic process for '#{iso}'" do
        expect(described_class.get(iso)).to be OpenChain::OfficialTariffProcessor::GenericProcessor
      end
    end
  end
end
