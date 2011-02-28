require 'test_helper'

class MasterSetupTest < ActiveSupport::TestCase
  # Replace this with your real tests.
  test "version" do
    v = Rails.root.join("config","version.txt").read
    assert MasterSetup.first.version==v, "Version should match content of version.txt"
  end
end
