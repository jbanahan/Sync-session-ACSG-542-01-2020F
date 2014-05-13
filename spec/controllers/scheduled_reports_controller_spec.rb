require 'spec_helper'

describe ScheduledReportsController do

  before :each do
    @user = Factory(:master_user,:email=>'a@example.com')

    sign_in_as @user
  end

  context :index do

    it "should find a users scheduled reports and custom reports and generate option values for them" do
      # Use a compound type to make sure we're translating it correctly
      @search_setup = Factory(:search_setup, :module_type=> "BrokerInvoice", :user => @user, :name => "A")
      @search_setup_2 = Factory(:search_setup, :module_type=> "BrokerInvoice", :user => @user, :name => "B")
      @search_setup_2.search_schedules.build :email_addresses => "me@there.com"
      @search_setup_2.search_runs.build :last_accessed => Time.zone.now
      @search_setup_2.save

      @custom_report = CustomReport.new :user => @user, :name => "A Custom Report"
      @custom_report.save

      @custom_report_2 = CustomReport.new :user => @user, :name => "B Custom Report"
      @custom_report_2.search_schedules.build :email_addresses => "me@there.com"
      @custom_report_2.report_results.build :run_at => Time.zone.now

      @custom_report_2.save

      get :index, :user_id => @user.id
      response.should be_success
      reports = assigns[:reports]

      # This should be an array suitable for passing to the rails helper method which creates
      # optgroups and option values for a select tag
      timeformat = "%m/%d/%Y %l:%M %p"

      # Report are ordered alphabetically by module and then individually by name
      reports.length.should == 2

      reports[0][0].should == "Broker Invoice"

      reports[0][1][0].should == [" #{@search_setup.name} - [unused]", "sr~#{@search_setup.id}"]
      reports[0][1][1].should == ["* #{@search_setup_2.name} - #{@search_setup_2.last_accessed.strftime(timeformat)}", "sr~#{@search_setup_2.id}"]

      reports[1][0].should == "Custom Report"
      reports[1][1][0].should == [" #{@custom_report.name} - [unused]", "cr~#{@custom_report.id}"]
      reports[1][1][1].should == ["* #{@custom_report_2.name} - #{@custom_report_2.report_results.first.run_at.strftime(timeformat)}", "cr~#{@custom_report_2.id}"]

      assigns[:user].id == @user.id
    end

    it "should error if user has no searches or scheduled reports" do
      get :index, :user_id => @user.id
      response.should be_redirect
      flash[:errors].should == ["#{@user.username} does not have any reports."]
    end

    it "should error if user doesn't exist" do
      get :index, :user_id => -1
      response.should be_redirect
      flash[:errors].should have(1).message
    end

    it "should error if non-admin user attempts to access another user's reports" do
      @user.update_attributes :admin => false, :sys_admin => false
      another_user = Factory(:user)

      get :index, :user_id => another_user.id
      response.should be_redirect
      flash[:errors].should have(1).message
    end
  end

  context :give_reports do

    before :each do
      @another_user = Factory(:user)
      @search_setup = Factory(:search_setup, :module_type=> "BrokerInvoice", :user => @user, :name => "A")
      @custom_report = CustomReport.new :user => @user, :name => "A Custom Report"
      @custom_report.search_schedules.build :email_addresses => "me@there.com"
      @custom_report.save
    end

    it "should give reports to another user" do
      put :give_reports, :user_id=> @user.id, :search_setup_id=>["sr~#{@search_setup.id}", "cr~#{@custom_report.id}"], :assign_to_user_id=>[@another_user.id]
      response.should redirect_to user_scheduled_reports_path(@user)

      # Another user should now have report copies
      search_copy = SearchSetup.find_by_user_id(@another_user.id)

      # Since we're using the SearchSetup's give functionality, just making
      # sure we found a result should be enough to determine that this works.
      search_copy.should_not be_nil

      custom_report_copy = CustomReport.find_by_user_id @another_user.id
      custom_report_copy.should_not be_nil
      custom_report_copy.search_schedules.length.should == 0
    end

    it "should give reports to another user and copy schedules" do
      put :give_reports, :user_id=> @user.id, :search_setup_id=>["cr~#{@custom_report.id}"], :assign_to_user_id=>[@another_user.id], :copy_schedules=>"true"
      response.should redirect_to user_scheduled_reports_path(@user)

      custom_report_copy = CustomReport.find_by_user_id @another_user.id
      custom_report_copy.should_not be_nil
      custom_report_copy.search_schedules.length.should == 1
    end

    it "should fail if user isn't found" do
      get :give_reports, :user_id=> -1
      response.should be_redirect
      flash[:errors].should have(1).message
    end

    it "should fail if non-admin user attempts to copy another user's reports" do
      @user.update_attributes :admin => false, :sys_admin => false
      put :give_reports, :user_id=> @another_user.id, :search_setup_id=>["sr~#{@search_setup.id}", "cr~#{@custom_report.id}"], :assign_to_user_id=>[@another_user.id]
      response.should be_redirect
      flash[:errors].should have(1).message
    end
  end
end