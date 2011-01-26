require 'test_helper'

class SearchSetupTest < ActiveSupport::TestCase
  # Replace this with your real tests.
  test "touch" do
    s = SearchSetup.new(:name => "touch test",:user => User.first,:module_type=>"Product")
    assert s.last_accessed.nil?, "last accessed should not have been touched"
    s.touch
    assert s.last_accessed > 3.seconds.ago, "Last accessed should be just now."
    assert s.id.nil?, "Should not have saved"
    s.last_accessed = 1.day.ago
    s.touch(true)
    assert s.last_accessed > 3.seconds.ago, "Last accessed should be just now."
    assert !s.id.nil?, "Should have saved"
  end
end
