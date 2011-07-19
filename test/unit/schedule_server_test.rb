require 'test_helper'

class ScheduleServerTest < ActiveSupport::TestCase

  #not really testing multi-thread concurrency, but testing sequential hits that are very similar.

  def setup
    ScheduleServer.destroy_all
  end

  test "check in - multiple hosts" do

    #base check in
    assert_equal "a", ScheduleServer.check_in("a")
    assert ScheduleServer.active_schedule_server?("a")
    assert !ScheduleServer.active_schedule_server?("b")

    #different host check in, doesn't overwrite
    assert_equal "a", ScheduleServer.check_in("b")
    assert ScheduleServer.active_schedule_server?("a")
    assert !ScheduleServer.active_schedule_server?("b")

    #make a's check in stale
    ScheduleServer.connection.execute "UPDATE schedule_servers SET `touch_time` = DATE_SUB(UTC_TIMESTAMP(), INTERVAL 90 SECOND);"

    #b host should take lock because a is 90 seconds old and therefore stale
    assert_equal "b", ScheduleServer.check_in("b")
    assert !ScheduleServer.active_schedule_server?("a")
    assert ScheduleServer.active_schedule_server?("b")

    #a host does not get lock back because b isn't stale
    assert_equal "b", ScheduleServer.check_in("a")
    assert !ScheduleServer.active_schedule_server?("a")
    assert ScheduleServer.active_schedule_server?("b")

    #confirm we only have 1 record
    assert_equal 1, ScheduleServer.count
  end

  test "initial check in creates object" do
    h = `hostname`.strip
    assert_equal 0, ScheduleServer.count
    
    assert_equal h, ScheduleServer.check_in

    assert_equal 1, ScheduleServer.count

    assert_equal h, ScheduleServer.first.host

    assert ScheduleServer.active_schedule_server?

    touch_time = ScheduleServer.first.touch_time
    now_time = (Time.now-1.minute)
    assert touch_time > now_time, "Expected ScheduleServer.first.touch_time to be greater than 1 minute ago: Touch_time: #{touch_time}, Now_time: #{now_time}"
  end

end
