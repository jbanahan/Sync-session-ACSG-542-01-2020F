require 'spec_helper'

describe OfficialTariffSpi do
  describe '#can_view?' do
    it "should defer to OfficialTariff" do
      u = double('user')
      ots = Factory(:official_tariff_spi)
      ots.official_tariff.should_receive(:can_view?).with(u).and_return true
      expect(ots.can_view?(u)).to be_true
    end
  end
end
