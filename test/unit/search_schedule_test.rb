require 'test_helper'
require 'mocha'

class SearchScheduleTest < ActiveSupport::TestCase

  def setup
    ActionMailer::Base.deliveries.clear
  end

  test "locked user" do
    FtpSender.expects(:send_file).never

    u = User.new(:username=>"lockeduser",:password=>"pwd123456",:password_confirmation=>"pwd123456",:company_id=>companies(:master).id,:email=>"unittest@chain.io")
    u.disabled = true #locking the user account should cause the schedules to do nothing
    u.save!

    search = u.search_setups.create!(:name=>"search_schedule_run",:module_type=>"Product")
    search.search_columns.create!(:rank=>1,:model_field_uid => "prod_uid")
    schedule = search.search_schedules.create!(:ftp_server => "server", :ftp_username=>"uname", 
        :ftp_password=>"pwd", :ftp_subfolder=>"fldr") 

    schedule.run #should do nothing, quietly
    
    schedule = search.search_schedules.create!(:email_addresses=>"unittest@aspect9.com") 

    schedule.run #should do nothing, quietly

    assert ActionMailer::Base.deliveries.empty?

  end

  test "run ftp - exception" do
    FtpSender.expects(:send_file).raises(IOError, 'mock IO Error')
    
    u = User.first
    search = u.search_setups.create!(:name=>"search_schedule_run",:module_type=>"Product")
    search.search_columns.create!(:rank=>1,:model_field_uid => "prod_uid")
    schedule = search.search_schedules.create!(:ftp_server => "server", :ftp_username=>"uname", 
        :ftp_password=>"pwd", :ftp_subfolder=>"fldr") 

    schedule.run

    assert !ActionMailer::Base.deliveries.empty?, "Error email should have been sent."

    mail = ActionMailer::Base.deliveries.pop
    assert mail[:to].to_s==u.email, "Error mail to should have been \"#{u.email}\", was \"#{mail[:to]}\""
    assert mail[:bcc].to_s=="support@chain.io", "Error mail should have BCC'd support."
    expected_subject = "[chain.io] Search Transmission Failure"
    assert mail[:subject].to_s == expected_subject, "Error mail subject should have been \"#{expected_subject}\", was \"#{mail[:subject].to_s}\""

    msg = u.messages.last
    expected_subject = "Search Transmission Failure"
    assert msg.subject==expected_subject, "Error subject should have been \"#{expected_subject}\", was \"#{mail[:subject].to_s}\""


  end
  test "run ftp" do
    FtpSender.expects(:send_file)

    u = User.first
    search = u.search_setups.create!(:name=>"search_schedule_run",:module_type=>"Product")
    search.search_columns.create!(:rank=>1,:model_field_uid => "prod_uid")
    schedule = search.search_schedules.create!(:ftp_server => "server", :ftp_username=>"uname", 
        :ftp_password=>"pwd", :ftp_subfolder=>"fldr") 

    schedule.run
    
    
  end

  test "run email" do
    FtpSender.expects(:send_file).never
    u = User.first
    search = u.search_setups.create!(:name=>"search_schedule_run",:module_type=>"Product")
    search.search_columns.create!(:rank=>1,:model_field_uid => "prod_uid")
    schedule = search.search_schedules.create!(:email_addresses=>"unittest@aspect9.com") 

    schedule.run

    assert !ActionMailer::Base.deliveries.empty?, "Email should have been sent."

    mail = ActionMailer::Base.deliveries.last
    assert mail[:to].to_s==schedule.email_addresses, "Email to should have been \"#{schedule.email_addresses}\", was \"#{mail[:to]}\""
  end

  test "reset_schedule" do
    scheduler = Rufus::Scheduler.start_new 
    scheduler.stop #so we don't actually run anything

    u = User.first
    search1 = u.search_setups.create!(:name=>"reset_schedule",:module_type=>"Product")
    ss1 = search1.search_schedules.create!(:run_monday=>true,:run_hour=>5)
    search2 = u.search_setups.create!(:name=>"reset_schedule2",:module_type=>"Product")
    ss2 = search2.search_schedules.create!(:run_tuesday=>true,:run_hour=>2)
    
    SearchSchedule.unschedule_jobs scheduler
    SearchSchedule.schedule_jobs scheduler
    
    jobs = scheduler.find_by_tag(SearchSchedule::RUFUS_TAG)
    assert jobs.length==2, "Should have found 2 jobs, found #{jobs.length}"

    assert ss2.destroy, "Destroy failed"

    jobs = scheduler.find_by_tag(SearchSchedule::RUFUS_TAG)
    assert jobs.length==2, "Should still find 2 jobs before resetting, found #{jobs.length}"

    SearchSchedule.unschedule_jobs scheduler
    SearchSchedule.schedule_jobs scheduler
    jobs = scheduler.find_by_tag(SearchSchedule::RUFUS_TAG)
    assert jobs.length==1, "Should find 1 job after resetting, found #{jobs.length}"
  end

  test "schedule" do
    scheduler = Rufus::Scheduler.start_new 
    scheduler.stop #so we don't actually run anything
    u = User.new(:username=>"cronstr",:password=>"abc123",:password_confirmation=>"abc123",
        :company_id=>companies(:vendor).id,:email=>"unittest@aspect9.com")
    u.time_zone = "Hawaii" #important to the test
    u.save!
    search = u.search_setups.create!(:name=>"cronstr",:module_type=>"Product")
    sched = search.search_schedules.create!(:run_hour=>3)

    
    sched.schedule scheduler
    assert scheduler.all_jobs.length==0, "Schedule with no days should not add a job, #{scheduler.all_jobs.length} jobs found."

    
    sched.update_attributes(:run_monday=>true,:run_wednesday=>true)
    sched.schedule scheduler

    jobs = scheduler.find_by_tag SearchSchedule::RUFUS_TAG
    assert jobs.length==1, "Should have one scheduled job under the RUFUS_TAG, had: #{jobs.length}"
    expected_cron = "0 3 * * 1,3 #{ActiveSupport::TimeZone::MAPPING[u.time_zone]}"
    assert jobs.first.t==expected_cron, "Should have had cron setting of #{expected_cron}, had \"#{jobs.first.t}\"" 
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
