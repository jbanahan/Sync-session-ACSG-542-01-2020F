require 'test_helper'

class TariffSetTest < ActiveSupport::TestCase
  test "activate" do
    c1 = Country.first
    c2 = Country.last
    assert c1!=c2 #setup check

    should_be_gone = OfficialTariff.create!(:country_id => c1.id, :hts_code=>"1234567890",:full_description=>"FD1")
    should_be_changed = OfficialTariff.create!(:country_id=>c1.id, :hts_code=>"1234555555",:full_description=>"FD3")
    should_stay = OfficialTariff.create!(:country_id => c2.id, :hts_code=>should_be_gone.hts_code, :full_description=>"FD2")

    old_ts = TariffSet.create!(:country_id=>c1.id,:label=>"oldts",:active=>true)

    ts = TariffSet.create!(:country_id=>c1.id,:label=>"newts")
    r = ts.tariff_set_records
    r.create!(:country_id=>c1.id,:hts_code=>should_be_changed.hts_code,:full_description=>"changed_desc")
    r.create!(:country_id=>c1.id,:hts_code=>"9999999999")

    ts.activate

    found = OfficialTariff.where(:country_id=>c1.id)

    assert_equal 2, found.size
    assert_equal "changed_desc", OfficialTariff.where(:country_id=>c1.id,:hts_code=>"1234555555").first.full_description
    assert OfficialTariff.where(:country_id=>c1.id,:hts_code=>"9999999999").first
    assert OfficialTariff.where(:country_id=>c2.id,:hts_code=>should_stay.hts_code).first
    assert_nil OfficialTariff.where(:country_id=>c1.id,:hts_code=>should_be_gone.hts_code).first
    assert !TariffSet.find(old_ts.id).active? #should have deactivated old tariff set for same country
    assert TariffSet.find(ts.id).active? #should have activated this tariff set
  end

  test "activate should write user message" do
    u = User.first
    c = Country.first
    ts = TariffSet.create!(:country_id=>c.id,:label=>"newts")
    ts.activate u
    assert_equal 1, u.messages.size
  end

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
