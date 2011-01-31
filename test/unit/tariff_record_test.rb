require 'test_helper'

class TariffRecordTest < ActiveSupport::TestCase
  test "clean hts" do
    h1 = "12,ABC34"
    h2 = "4711.23.23.23"
    h3 = "abcdefghi"
    c = TariffRecord.new(:hts_1=>h1,:hts_2=>h2,:hts_3=>h3)
    assert c.hts_1=="1234", "HTS1 was #{c.hts_1}, should have been '1234'"
    assert c.hts_2=="4711232323", "HTS2 was #{c.hts_2}, should have been '4711232323'"
    assert c.hts_3=="", "HTS3 was #{c.hts_3}, should have been ''"
  end
end
