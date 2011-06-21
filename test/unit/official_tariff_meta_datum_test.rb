require 'test_helper'

class OfficialTariffMetaDatumTest < ActiveSupport::TestCase
  test "find official tariff" do
    ot = OfficialTariff.create!(:country_id => Country.first.id, :hts_code=>"999777666",:full_description=>"fd")
    otmd = OfficialTariffMetaDatum.create(:country_id=>ot.country_id,:hts_code=>ot.hts_code)
    found = otmd.official_tariff
    assert found==ot
  end
end
