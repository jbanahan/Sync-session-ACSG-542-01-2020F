require 'test_helper'
require 'mocha'

class SearchScheduleTest < ActiveSupport::TestCase

  test "next_run_time - " do 
    u = User.new(:username=>"nrt",:password=>"abc123",:password_confirmation=>"abc123",
        :email=>"unittest@aspect9.com",:company_id=>companies(:vendor).id)
    u.time_zone = 'Eastern Time (US & Canada)'
    u.save!
    search_setup = u.search_setups.create!(:module_type=>"Product",:name=>"nrt")
    schedule = search_setup.search_schedules.new(:run_saturday=>true,:run_hour=>22,:last_start_time=>Time.new(2011,2,25))
  
    Time.expects(:now).at_least_once.returns(Time.new(2011,3,6,4,0,0,0)) #March 6 4am UTC, March 5 11pm EST

    assert schedule.next_run_time == Time.new(2011,3,6,4,0,0,0), "Should have next run time of March 6, 4am UTC, had #{schedule.next_run_time}"

  end
  test "needs_run? - currently running" do
    assert false, "implement test"
  end

  test "needs_run? - not running / past next_run_time" do
    assert false, "implement test"
  end

  test "needs_run? - not running / before next_run_time" do
    assert false, "implement test"
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
