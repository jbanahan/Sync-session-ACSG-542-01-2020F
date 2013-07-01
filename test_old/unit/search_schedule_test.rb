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


end
