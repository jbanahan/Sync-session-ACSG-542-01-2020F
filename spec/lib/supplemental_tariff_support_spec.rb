describe OpenChain::SupplementalTariffSupport do
  subject do
    Class.new do
      include OpenChain::SupplementalTariffSupport
    end.new
  end

  describe 'mtb_tariff?' do
    it 'identifies MTB tariff' do
      expect(subject.mtb_tariff?('99020101')).to eq true
      expect(subject.mtb_tariff?('99038801')).to eq false
    end
  end

  describe 'is_301_tariff?' do
    it 'identifies 301 tariff' do
      expect(subject.is_301_tariff?('99038801')).to eq true
      expect(subject.is_301_tariff?('99020101')).to eq false
    end
  end

  describe 'supplemental_98_tariff?' do
    it 'identifies special provisions chapter' do
      expect(subject.supplemental_98_tariff?('98020101')).to eq true
      expect(subject.supplemental_98_tariff?('99020101')).to eq false
    end
  end

  describe 'supplemental_tariff?' do
    it 'identifies 301 tariffs' do
      expect(subject.supplemental_tariff?('99038801')).to eq true
    end

    it 'identifies MTB tariffs' do
      expect(subject.supplemental_tariff?('99020101')).to eq true
    end

    it 'identifies special provisions chapter' do
      expect(subject.supplemental_tariff?('98020101')).to eq true
    end

    it 'does not identify standard tariff numbers' do
      expect(subject.supplemental_tariff?('6201')).to eq false
    end
  end
end
