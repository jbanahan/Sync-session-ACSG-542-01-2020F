require 'test_helper'

class OfficialTariffTest < ActiveSupport::TestCase

  test "binding ruling url" do
    t = OfficialTariff.new(:country_id=>Country.where(:iso_code=>"US").first.id,:hts_code=>"1234567890")
    found = t.binding_ruling_url
    expected = "http://rulings.cbp.gov/index.asp?qu=1234%2E56%2E7890&vw=results" 
    assert found==expected
    t.country=Country.where(:iso_code=>"IT").first
    expected = "http://ec.europa.eu/taxation_customs/dds2/ebti/ebti_consultation.jsp?Lang=en&nomenc=123456&orderby=0&Expand=true&offset=1&range=25"
    found = t.binding_ruling_url
    assert found==expected, "Expected: #{expected}, Found: #{found}"
    t.country=Country.where(:iso_code=>"CN").first
    assert t.binding_ruling_url.nil?
  end

  test "as_json" do
    hts_seed = "1234567890"
    t = OfficialTariff.create!(:country_id=>countries(:us).id,:hts_code=>hts_seed,:full_description=>"XB")
    j = t.as_json["official_tariff"]
    assert j["hts_code"]==hts_seed.hts_format
    assert j["notes"] == ""
    assert j["auto_classify_ignore"] == false
    assert j["binding_ruling_url"] =="http://rulings.cbp.gov/index.asp?qu=1234%2E56%2E7890&vw=results"
    md = t.meta_data
    md.auto_classify_ignore = true
    md.notes="123abc"
    j = t.as_json["official_tariff"]
    assert j["notes"]=="123abc", "Expected 123abc, got #{j["notes"]}"
    assert j["auto_classify_ignore"]

    t.country = Country.where(:iso_code=>"CN").first
    j = t.as_json["official_tariff"]
    assert j["binding_ruling_url"].nil?
  end

  test "meta_data" do
    t = OfficialTariff.create!(:country_id=>Country.first.id,:hts_code=>"5165615",:full_description=>"FD")
    #getting meta data before it's created should work like .build
    otmd = t.meta_data
    assert otmd.id.nil?
    assert otmd.is_a?(OfficialTariffMetaData)
    assert otmd.hts_code==t.hts_code
    assert otmd.country_id==t.country_id
    otmd.notes = "abcdd"
    otmd.save!
    found = OfficialTariff.find(t.id).meta_data
    assert otmd==found
  end

  test "find cached by hts code and country id" do
    t = OfficialTariff.create!(:country_id=>countries(:us).id,:hts_code=>"7777777777",:full_description=>"FA")
    found = OfficialTariff.find_cached_by_hts_code_and_country_id "7777777777", countries(:us).id
    assert t == found
  end

  test "find matches" do
    us = countries(:us)
    china = countries(:china)
    ust = OfficialTariff.create!(:country=>us,:hts_code=>"1234567890",:full_description=>"FD")
    china_hts_nums = ["12345670123","1234569876","00000000"]
    china_hts_nums.each do |h|
      OfficialTariff.create!(:country=>china,:hts_code=>h,:full_description=>"FD")
    end
    results = ust.find_matches(china)
    assert results.length==2, "Should find 2 results, found #{results.length}"
    found_1 = false
    found_2 = false
    results.each do |r|
      assert r.country==china, "Result should be for China, was for #{r.country.name}"
      found_1 = true if r.hts_code==china_hts_nums[0]
      found_2 = true if r.hts_code==china_hts_nums[1]
    end
    assert found_1 && found_2, "Should have found both HTS numbers"
  end
end
