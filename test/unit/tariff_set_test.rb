require 'test_helper'

class TariffSetTest < ActiveSupport::TestCase
  test "compare" do
    old = TariffSet.create!(:country_id=>countries(:us).id,:label=>"old")
    new = TariffSet.create!(:country_id=>countries(:us).id,:label=>"new")

    #will be removed
    old.tariff_set_records.create!(:hts_code=>"123",:country_id=>old.country_id)
    #will be changed
    old.tariff_set_records.create!(:hts_code=>"345",:full_description=>"abc",:country_id=>old.country_id)
    #will stay the same
    old.tariff_set_records.create!(:hts_code=>"901",:full_description=>"xyz",:country_id=>old.country_id)

    #changed
    new.tariff_set_records.create!(:hts_code=>"345",:full_description=>"def",:country_id=>new.country_id)
    #added
    new.tariff_set_records.create!(:hts_code=>"567",:country_id=>new.country_id)
    #stayed the same
    new.tariff_set_records.create!(:hts_code=>"901",:full_description=>"xyz",:country_id=>new.country_id)

    added, removed, changed = new.compare old

    assert_equal 1, added.size
    assert_equal "567", added.first.hts_code
    assert_equal 1, removed.size
    assert_equal "123", removed.first.hts_code
    assert_equal 1, changed.size
    assert_equal "def", changed["345"][0]["full_description"]
    assert_equal "abc", changed["345"][1]["full_description"]
  end
end 
