require 'test_helper'

class OfficialTariffMetaDataTest < ActiveSupport::TestCase
  test "find official tariff" do
    ot = OfficialTariff.create!(:country_id => Country.first.id, :hts_code=>"999777666",:full_description=>"fd")
    otmd = OfficialTariffMetaData.create(:country_id=>ot.country_id,:hts_code=>ot.hts_code)
    found = otmd.official_tariff
    assert found==ot
  end
end
