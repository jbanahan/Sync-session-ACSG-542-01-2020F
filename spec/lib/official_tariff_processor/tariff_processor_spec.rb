require 'spec_helper'

describe OpenChain::OfficialTariffProcessor::TariffProcessor do
  describe :process_country do
    it "should do nothing if country not in registry" do
      c = double(:country)
      OpenChain::OfficialTariff::TariffProcessorRegistry.should_receive(:get).with(c).and_return nil
      # shouldn't fail
      described_class.process_country(c)
    end
    it "should create unique list with one of each tariff not already containing keys" do
      ep = OpenChain::OfficialTariffProcessor::EuProcessor
      c = Factory(:country,iso_code:'IT')
      spi_already_processed = 'Free: (PE)'
      tariff_already_processed = Factory(:official_tariff,country:c,special_rates:spi_already_processed)
      SpiRate.create!(
        special_rate_key:tariff_already_processed.special_rate_key,
        country_id:c.id,
        rate:0,
        rate_text:'Free'
      )

      new_spi1 = Factory(:official_tariff,country:c,special_rates:'Free: (CO)')
      new_spi2 = Factory(:official_tariff,country:c,special_rates:'Free: (CO,PE)')

      # ignore new tariff with spi that has already been written
      Factory(:official_tariff,special_rates:spi_already_processed)
      # ignore second tariff with same special rates
      Factory(:official_tariff,country:c,special_rates:'Free: (CO)')
      # ignore blank spi
      Factory(:official_tariff,country:c,special_rates:nil)
      # ignore for another country
      Factory(:official_tariff,special_rates:'Free: (CO)')

      ep.should_receive(:process).once.with(new_spi1).ordered
      ep.should_receive(:process).once.with(new_spi2).ordered

      described_class.process_country c
    end
  end
end
