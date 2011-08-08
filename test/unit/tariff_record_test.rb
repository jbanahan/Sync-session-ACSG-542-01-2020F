require 'test_helper'

class TariffRecordTest < ActiveSupport::TestCase
  test "has_schedule_b" do
    t = TariffRecord.new(:hts_1=>"123")
    assert !t.has_schedule_b?
    t.schedule_b_1 = '1'
    assert t.has_schedule_b?
    t.schedule_b_1 = nil
    t.schedule_b_2 = '2'
    assert t.has_schedule_b?
    t.schedule_b_2 = nil
    t.schedule_b_3 = '3'
    assert t.has_schedule_b?
  end

  test "clean hts" do
    h1 = "12,ABC34"
    h2 = "4711.23.23.23"
    h3 = "abcdefghi"
    c = TariffRecord.new(:hts_1=>h1,:hts_2=>h2,:hts_3=>h3,:schedule_b_1=>h1,:schedule_b_2=>h2,:schedule_b_3=>h3)
    assert c.hts_1=="1234", "HTS1 was #{c.hts_1}, should have been '1234'"
    assert c.hts_2=="4711232323", "HTS2 was #{c.hts_2}, should have been '4711232323'"
    assert c.hts_3=="", "HTS3 was #{c.hts_3}, should have been ''"
    assert c.schedule_b_1=="1234", "s1 was #{c.schedule_b_1}, should have been '1234'"
    assert c.schedule_b_2=="4711232323", "s2 was #{c.schedule_b_2}, should have been '4711232323'"
    assert c.schedule_b_3=="", "s3 was #{c.schedule_b_3}, should have been ''"
  end

  test "line_number" do
    c = Classification.create!(:product_id => Product.first,:country_id=>Country.last)
    t = c.tariff_records.create!
    assert t.line_number == 1, "Line number should be 1, was #{t.line_number}"
  end

  test "hts_#_official_tariff" do
    cntry = Country.first
    ot1 = OfficialTariff.create!(:full_description=>"FD",:country_id=>cntry,:hts_code=>"991199")
    ot2 = OfficialTariff.create!(:full_description=>"FD2",:country_id=>cntry,:hts_code=>"444111")
    ot3 = OfficialTariff.create!(:full_description=>"FD3",:country_id=>cntry,:hts_code=>"44885566")
    c = Classification.create!(:country_id=>cntry,:product_id=>Product.first)
    t = c.tariff_records.build(:hts_1=>ot1.hts_code,:hts_2=>ot2.hts_code,:hts_3=>ot3.hts_code)
    assert ot1==t.hts_1_official_tariff, "Expected official tariff #{ot1.id}, got #{t.hts_1_official_tariff.id}"
    assert ot2==t.hts_2_official_tariff
    assert ot3==t.hts_3_official_tariff
    t.hts_1 = ot1.hts_code+"111"
    t.hts_2 = nil
    assert t.hts_1_official_tariff.nil?
    assert t.hts_2_official_tariff.nil?
  end
end
