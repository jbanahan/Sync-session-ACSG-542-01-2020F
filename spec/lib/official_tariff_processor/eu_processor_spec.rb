require 'spec_helper'

describe OpenChain::OfficialTariffProcessor::EuProcessor do
  let(:eu_tariff) do
    Factory(:official_tariff, hts_code:'0101300000',
      country:Factory(:country,iso_code:'IT'),
      special_rates: '	3.2%: (SPGL - TarrPref Excl), 9999.99%: (KP - North Korea - I), Free: (AL,DZ,AD- CstUnDty,XC,CL,EPA,EG,TOUT- NonPrfTQ,EEA,SWITZ,FO,MK,IL,JO,LB,XL,MX,ME,MA,PS,S M- CstUnDty,ZA,CH,SY,TN,TR- CstUnDty,BA - Tariff preferen,XK - Tariff preferen,XS - Tariff preferen,EU,ERGA OMNES - Airwort,PG - Tariff preferen,CARI - TarrPref Excl,ESA - Tariff Prefere,KR - Preferential ta,KR - Tariff Preferen,MD - Tariff Preferen,PE - Tariff Preferen,CO - Tariff Preferen,CAMER - Tariff Prefe,SPGA - Tariff prefer,UA - Tariff preferen,FJ - Fiji,CM - Tariff preferen,GE - Tariff preferen,EC - Tariff preferen,SPGE - PrefTariff,LOMB - TARIFF PREFER)'
    )
  end
  describe '#process' do
    it 'should parse spi items for EU-PERU, EU-COLUMBIA' do
      ot = eu_tariff
      expect{described_class.process(ot)}.to change(SpiRate,:count).from(0).to(2)
      ot.reload
      expect(ot.special_rate_key).to_not be_blank
      expect(SpiRate.where(country_id:ot.country_id,special_rate_key:ot.special_rate_key,rate_text:'Free',rate:0).where("program_code IN ('CO','PE')").count).to eq 2
    end
  end
end
