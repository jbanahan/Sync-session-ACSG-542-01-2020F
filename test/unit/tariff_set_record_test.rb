require 'test_helper'

class TariffSetRecordTest < ActiveSupport::TestCase

  test "build_official_tariff" do 
    t = TariffSetRecord.new(:country_id=>1,:full_description=>"abc",:chapter=>"chpt",:hts_code=>"12345678",:tariff_set_id=>1,:created_at=>Time.now,:updated_at=>Time.now)
    ot = t.build_official_tariff
    assert_equal 1, ot.country_id
    assert_equal "abc", ot.full_description
    assert_equal "chpt", ot.chapter
    assert_equal "12345678", ot.hts_code
  end

  test "compare" do
    #tariff_set_id should be ignored for comparison purposes

    t1 = TariffSetRecord.new(:country_id=>1,:full_description=>"abc",:hts_code=>"1234567890",:tariff_set_id=>1)
    t2 = TariffSetRecord.new(:country_id=>1,:full_description=>"def",:heading=>"aab",:tariff_set_id=>2)

    t1_return, t2_return = t1.compare t2

    assert_equal 3, t1_return.size
    assert_equal 3, t2_return.size

    assert_equal "abc", t1_return["full_description"]
    assert_equal "1234567890", t1_return["hts_code"]
    assert_nil t1_return["heading"]

    assert_equal "def", t2_return["full_description"]
    assert_equal "aab", t2_return["heading"]
    assert_nil t2_return["hts_code"]
  end

end
