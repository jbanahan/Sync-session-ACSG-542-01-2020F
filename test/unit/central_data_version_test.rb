require 'test_helper'
require 'open_chain/central_data'


class CentralDataVersionTest < ActiveSupport::TestCase

  def teardown
    OpenChain::CentralData::Version.destroy_all
  end

  test "create version" do
    v = OpenChain::CentralData::Version.create!("cv","pass")
    
    assert_equal "cv", v.name
    assert_equal "pass", v.upgrade_password
    
    v2 = OpenChain::CentralData::Version.get("cv")


    assert_equal v.name, v2.name
    assert_equal v.upgrade_password, v2.upgrade_password

    v2.destroy

    assert_nil OpenChain::CentralData::Version.get("cv")
  end

end
