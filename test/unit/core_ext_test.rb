require 'test_helper'
 
class CoreExtTest < ActiveSupport::TestCase 

  test "Spreadsheet Float" do
    wb = Spreadsheet::Workbook.new
    s = wb.create_worksheet
    r = s.row(0)
    flt = 1.1
    flt_1 = 1.0
    int = 2
    str = "2"
    r.push flt
    r.push flt_1
    r.push int
    r.push str

    flt_r = r[0]
    flt_1_r = r[1]
    int_r = r[2]
    str_r = r[3]
    assert flt_r.is_a?(Float), "Should be a float"
    assert flt_1_r.is_a?(Fixnum), "Should be a fixnum, was #{flt_1_r.class.to_s}"
    assert flt_1_r.to_s=="1"
    assert int_r.is_a?(Fixnum)
    assert int_r.to_s=="2"
    assert str_r=="2"
  end

  test "hts formatting" do
    test_map = {
      ""=>"",
      "1"=>"1",
      "12"=>"12",
      "123"=>"123",
      "1234"=>"1234",
      "12345"=>"12345",
      "123456"=>"1234.56",
      "1234567"=>"1234.567",
      "12345678"=>"1234.56.78",
      "123456789"=>"1234.56.789",
      "1234567890"=>"1234.56.78.90",
      "1234567890123"=>"1234.56.78.90123",
      "1234.5.6"=>"1234.56", #cleanup periods
      "12x34.56"=>"12x34.56", #ignore anything with letters
      "12 34 56"=>"1234.56" #cleanup spaces
    }
    test_map.each do |given,expected|
      found = given.hts_format
      assert found==expected, "Expected \"#{expected}\", got \"#{found}\""
    end
  end

end
