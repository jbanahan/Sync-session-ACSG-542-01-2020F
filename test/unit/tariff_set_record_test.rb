require 'test_helper'

class TariffSetRecordTest < ActiveSupport::TestCase

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
