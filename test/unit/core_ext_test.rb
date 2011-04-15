require 'test_helper'
 
class CoreExtTest < ActiveSupport::TestCase 

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
