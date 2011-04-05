require 'test_helper'

class OfficialQuotaTest < ActiveSupport::TestCase
  # Replace this with your real tests.
  test "link" do
    c = Country.first
    hts = "123456789"
    q = OfficialQuota.create!(:country_id=>c,:hts_code=>hts)
    t = OfficialTariff.create!(:country_id=>c,:hts_code=>hts,:full_description=>"ABD")
    q.link
    assert q.official_tariff==t
  end
end
