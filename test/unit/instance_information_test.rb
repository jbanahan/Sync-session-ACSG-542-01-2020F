require 'test_helper'

class InstanceInformationTest < ActiveSupport::TestCase

  test "check_in" do

    InstanceInformation.destroy_all #make sure we're starting clean

    InstanceInformation.check_in

    assert_equal 1, InstanceInformation.all.size

    ii = InstanceInformation.first

    assert ii.last_check_in > 2.seconds.ago

    assert_equal `hostname`.strip, ii.host
    assert_equal MasterSetup.get.version, ii.version

    #make sure we delay long enough to get a new check in time
    sleep 1

    #checking in again shouldn't create a new record, but should update time
    InstanceInformation.check_in

    assert_equal 1, InstanceInformation.all.size

    assert ii.last_check_in < InstanceInformation.first.last_check_in, "Expected change in last_check_in time, ii: #{ii.last_check_in}, current: #{InstanceInformation.first.last_check_in}"

    #checking in with a different host name should crate a new record

    InstanceInformation.check_in "hn"
    assert_equal 2, InstanceInformation.all.size

  end

end
