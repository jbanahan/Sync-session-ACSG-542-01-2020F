require 'test_helper'
require 'spreadsheet'
class TariffLoaderTest < ActiveSupport::TestCase

  test "s3 auto activate" do
    wb = Spreadsheet::Workbook.new
    sheet = wb.create_worksheet
    cols = ["HSCODE","FULL_DESC","SPC_RATES","UNITCODE","GENERAL","CHAPTER","HEADING","SUBHEADING","REST_DESC","ADDVALOREMRATE","PERUNIT","MFN","GPT","ERGA_OMNES","COL2_RATE",
      "Import Reg 1","Import Reg 2","Import Reg 3","Import Reg 4","Export Reg 1","Export Reg 2","Export Reg 3","Export Reg 4"]
    row1_data = []
    row2_data = []
    row1_expected = {}
    row2_expected = {}
    cols.each_index do |i|
      s1 = "val-#{i}"
      s2 = "s2-#{i}"
      row1_data << s1
      row2_data << s2
      row1_expected[cols[i]] = s1
      row2_expected[cols[i]] = s2
    end
    sheet.row(0).replace cols
    sheet.row(1).replace row1_data
    sheet.row(2).replace row2_data
    t = Tempfile.new(["tariffloadertest-general",".xls"])
    wb.write t.path

    country = Country.first
    label = "ABCDEFS3A"

    #PUT THE FILE TO S3
    s3 = AWS::S3.new AWS_CREDENTIALS
    begin
      key = "#{Rails.env.to_s}/TariffStore/#{t.path.split('/').last}"
      s3.buckets['chain-io'].objects[key].write(:file=>t.path)
      TariffLoader.process_s3 key, country, label, true
    ensure
      s3.buckets['chain-io'].objects[key].delete
    end

    ts = TariffSet.where(:label=>label).first
    assert_equal country, ts.country
    assert_equal 2, ts.tariff_set_records.size
    
    ot = OfficialTariff.where(:country_id=>country.id)
    assert_equal 2, ot.size
    expected_hts = ts.tariff_set_records.collect {|tsr| tsr.hts_code}
    ot.each {|o| expected_hts.delete o.hts_code}
    assert expected_hts.empty?
  end
  test "s3" do 
    wb = Spreadsheet::Workbook.new
    sheet = wb.create_worksheet
    cols = ["HSCODE","FULL_DESC","SPC_RATES","UNITCODE","GENERAL","CHAPTER","HEADING","SUBHEADING","REST_DESC","ADDVALOREMRATE","PERUNIT","MFN","GPT","ERGA_OMNES","COL2_RATE",
      "Import Reg 1","Import Reg 2","Import Reg 3","Import Reg 4","Export Reg 1","Export Reg 2","Export Reg 3","Export Reg 4"]
    row1_data = []
    row2_data = []
    row1_expected = {}
    row2_expected = {}
    cols.each_index do |i|
      s1 = "val-#{i}"
      s2 = "s2-#{i}"
      row1_data << s1
      row2_data << s2
      row1_expected[cols[i]] = s1
      row2_expected[cols[i]] = s2
    end
    sheet.row(0).replace cols
    sheet.row(1).replace row1_data
    sheet.row(2).replace row2_data
    t = Tempfile.new(["tariffloadertest-general",".xls"])
    wb.write t.path

    country = Country.first
    label = "ABCDEFS3"

    #PUT THE FILE TO S3
    s3 = AWS::S3.new AWS_CREDENTIALS
    begin
      key = "#{Rails.env.to_s}/TariffStore/#{t.path.split('/').last}"
      s3.buckets['chain-io'].objects[key].write(:file=>t.path)
      TariffLoader.process_s3 key, country, label, false
    ensure
      s3.buckets['chain-io'].objects[key].delete
    end
    ts = TariffSet.where(:label=>label).first
    assert_equal country, ts.country
    assert_equal 2, ts.tariff_set_records.size
  end

  test "activate" do 
    wb = Spreadsheet::Workbook.new
    sheet = wb.create_worksheet
    cols = ["HSCODE","FULL_DESC","SPC_RATES","UNITCODE","GENERAL","CHAPTER","HEADING","SUBHEADING","REST_DESC","ADDVALOREMRATE","PERUNIT","MFN","GPT","ERGA_OMNES","COL2_RATE",
      "Import Reg 1","Import Reg 2","Import Reg 3","Import Reg 4","Export Reg 1","Export Reg 2","Export Reg 3","Export Reg 4"]
    row1_data = []
    row2_data = []
    row1_expected = {}
    row2_expected = {}
    cols.each_index do |i|
      s1 = "val-#{i}"
      s2 = "s2-#{i}"
      row1_data << s1
      row2_data << s2
      row1_expected[cols[i]] = s1
      row2_expected[cols[i]] = s2
    end
    sheet.row(0).replace cols
    sheet.row(1).replace row1_data
    sheet.row(2).replace row2_data
    t = Tempfile.new(["us_tariffloadertest-general",".xls"])
    wb.write t.path

    label = "ABCDEF"
    country = Country.where(:iso_code=>'US').first

    TariffLoader.process_file t.path, label, true

    ts = OfficialTariff.where(:country_id=>country.id) 
    assert_equal 2, ts.size
    result1 = ts.where(:country_id=>country.id,:hts_code=>row1_data[0]).first
    result2 = ts.where(:country_id=>country.id,:hts_code=>row2_data[0]).first
    [result1,result2].each do |r|
      exp = r.hts_code==row1_data[0] ? row1_expected : row2_expected
      assert r.full_description==exp["FULL_DESC"]
      assert r.special_rates==exp["SPC_RATES"]
      assert r.unit_of_measure==exp["UNITCODE"]
      assert r.general_rate==exp["GENERAL"]
      assert r.chapter==exp["CHAPTER"]
      assert r.heading==exp["HEADING"]
      assert r.sub_heading==exp["SUBHEADING"]
      assert r.remaining_description==exp["REST_DESC"]
      assert r.add_valorem_rate==exp["ADDVALOREMRATE"]
      assert r.per_unit_rate==exp["PERUNIT"]
      assert r.most_favored_nation_rate==exp["MFN"]
      assert r.general_preferential_tariff_rate==exp["GPT"]
      assert r.erga_omnes_rate==exp["ERGA_OMNES"]
      assert r.column_2_rate==exp["COL2_RATE"]
      assert r.import_regulations == "#{exp["Import Reg 1"]} #{exp["Import Reg 2"]} #{exp["Import Reg 3"]} #{exp["Import Reg 4"]}"
      assert r.export_regulations == "#{exp["Export Reg 1"]} #{exp["Export Reg 2"]} #{exp["Export Reg 3"]} #{exp["Export Reg 4"]}"
    end
  end
  test "general" do
    wb = Spreadsheet::Workbook.new
    sheet = wb.create_worksheet
    cols = ["HSCODE","FULL_DESC","SPC_RATES","UNITCODE","GENERAL","CHAPTER","HEADING","SUBHEADING","REST_DESC","ADDVALOREMRATE","PERUNIT","MFN","GPT","ERGA_OMNES","COL2_RATE",
      "Import Reg 1","Import Reg 2","Import Reg 3","Import Reg 4","Export Reg 1","Export Reg 2","Export Reg 3","Export Reg 4"]
    row1_data = []
    row2_data = []
    row1_expected = {}
    row2_expected = {}
    cols.each_index do |i|
      s1 = "val-#{i}"
      s2 = "s2-#{i}"
      row1_data << s1
      row2_data << s2
      row1_expected[cols[i]] = s1
      row2_expected[cols[i]] = s2
    end
    sheet.row(0).replace cols
    sheet.row(1).replace row1_data
    sheet.row(2).replace row2_data
    t = Tempfile.new(["tariffloadertest-general",".xls"])
    wb.write t.path

    country = Country.first
    label = "ABCDEF"
    loader = TariffLoader.new(country,t.path,label)
    
    loader.process


    ts = TariffSet.where(:label=>label).first
    assert_equal label, ts.label
    assert_equal country, ts.country
    assert_equal 2, ts.tariff_set_records.size
    result1 = ts.tariff_set_records.where(:country_id=>country.id,:hts_code=>row1_data[0]).first
    result2 = ts.tariff_set_records.where(:country_id=>country.id,:hts_code=>row2_data[0]).first
    [result1,result2].each do |r|
      exp = r.hts_code==row1_data[0] ? row1_expected : row2_expected
      assert r.full_description==exp["FULL_DESC"]
      assert r.special_rates==exp["SPC_RATES"]
      assert r.unit_of_measure==exp["UNITCODE"]
      assert r.general_rate==exp["GENERAL"]
      assert r.chapter==exp["CHAPTER"]
      assert r.heading==exp["HEADING"]
      assert r.sub_heading==exp["SUBHEADING"]
      assert r.remaining_description==exp["REST_DESC"]
      assert r.add_valorem_rate==exp["ADDVALOREMRATE"]
      assert r.per_unit_rate==exp["PERUNIT"]
      assert r.most_favored_nation_rate==exp["MFN"]
      assert r.general_preferential_tariff_rate==exp["GPT"]
      assert r.erga_omnes_rate==exp["ERGA_OMNES"]
      assert r.column_2_rate==exp["COL2_RATE"]
      assert r.import_regulations == "#{exp["Import Reg 1"]} #{exp["Import Reg 2"]} #{exp["Import Reg 3"]} #{exp["Import Reg 4"]}"
      assert r.export_regulations == "#{exp["Export Reg 1"]} #{exp["Export Reg 2"]} #{exp["Export Reg 3"]} #{exp["Export Reg 4"]}"
    end
  end

end
