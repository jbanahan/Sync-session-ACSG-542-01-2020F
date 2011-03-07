require 'test_helper'

class SearchScheduleTest < ActiveSupport::TestCase

  test "cron_string" do
    u = User.new(:username=>"cronstr",:password=>"abc123",:password_confirmation=>"abc123",
        :company_id=>companies(:vendor).id,:email=>"unittest@aspect9.com")
    u.time_zone = "Hawaii" #important to the test
    u.save!
    search = u.search_setups.create!(:name=>"cronstr",:module_type=>"Product")
    schedule = search.search_schedules.create!(:run_monday=>true,:run_wednesday=>true,:run_hour=>3)

    expected = "* 3 * * 1,3 Hawaii"
    assert schedule.cron_string == expected, "Expected cron_string to be '#{expected}', was '#{schedule.cron_string}'"

    schedule.run_monday = false
    schedule.run_wednesday = false
    #cron string should be nil if no days are set
    assert schedule.cron_string.nil?, "Expected cron_string to be nil if no days are set."
  end

  test "is_running? - never finished" do 
    s = SearchSchedule.new(:last_start_time => 3.minutes.ago)
    assert s.is_running?, "Should have returned running with start time in past & no finish time"
  end

  test "is_running? - never started" do
    s = SearchSchedule.new
    assert !s.is_running?, "Should have returned false with no start time"
  end

  test "is_running? - started after finished" do
    s = SearchSchedule.new(:last_start_time => 3.minutes.ago, :last_finish_time => 5.minutes.ago)
    assert s.is_running?, "Should have returned true with start time after finish time"
  end

  test "is_running? - started before finished" do
    s = SearchSchedule.new(:last_start_time => 3.minutes.ago, :last_finish_time => Time.now)
    assert !s.is_running?, "Should have returned false with start time before finish time"
  end
end
