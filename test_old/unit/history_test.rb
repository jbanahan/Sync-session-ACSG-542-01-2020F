require 'test_helper'

class HistoryTest < ActiveSupport::TestCase
  # Replace this with your real tests.
  test "details_hash" do
    h = History.find(1)
    d_count = HistoryDetail.count(:conditions => "history_id = 1")
    d_hash = h.details_hash
    assert d_count == d_hash.length, "Detail count (#{d_count}) != detail hash length (#{d_hash.length})"
    assert d_hash[:key1] == "val1", "Key1 didn't equal 'val1', it was '#{d_hash[:key1].to_s}'"
    assert d_hash[:key2] == "val2", "Key2 didn't equal 'val2', it was '#{d_hash[:key2].to_s}'"
  end
end
