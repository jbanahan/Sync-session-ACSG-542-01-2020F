require 'test_helper'

class OfficialScheduleBCodeTest < ActiveSupport::TestCase

  test "load from census file" do
    file = 'test/assets/schedule_b.txt'
    assert OfficialScheduleBCode.first.nil?

    assert_equal 2, OfficialScheduleBCode.load_from_census_file(file)

    assert_equal 2, OfficialScheduleBCode.count

    b = OfficialScheduleBCode.where(:hts_code=>'0101901000').first
    assert_equal "HORSES, LIVE, EXCEPT PUREBRED BREEDING", b.short_description
    assert_equal "HORSES, LIVE, EXCEPT PUREBRED BREEDING", b.long_description
    assert_equal "NO", b.quantity_1
    assert_equal "", b.quantity_2
    assert_equal "00150", b.sitc_code
    assert_equal "10140", b.end_use_classification
    assert_equal "0", b.usda_code
    assert_equal "112920", b.naics_classification
    assert_equal "00", b.hitech_classification

    #run again, make sure we don't have duplicate records
    OfficialScheduleBCode.load_from_census_file file
    assert_equal 2, OfficialScheduleBCode.count
  end

end
