require 'spec_helper'

describe ReportResultsController do
  
  before(:each) do
    c = Company.create!(:name=>'btestc')
    @base_user = User.create!(:email=>'basetest@aspect9.com',:username=>'base_test',:password=>'b12345',:password_confirmation=>'b12345',:company_id=>c.id)
    @admin_user = User.create!(:email=>'admintest@aspect9.com',:username=>'admin_test',:password=>'b12345',:password_confirmation=>'b12345',:company_id=>c.id)
    @admin_user.sys_admin = true
    [@base_user,@admin_user].each do |u|
      u.tos_accept = Time.now
      u.save!
    end
    2.times do |i|
      @base_report = ReportResult.create!(:name=>'base_report',:run_by_id=>@base_user.id)
      @admin_report = ReportResult.create!(:name=>'admin_report',:run_by_id=>@admin_user.id)
    end
    activate_authlogic
  end
  
  describe 'index' do

    context 'non-admin user' do
      before(:each) do
        UserSession.create @base_user #log in
      end

      it "should show only their reports, even with flag for show all turned on" do
        get :index, :show_all=>'true'
        response.should be_success
        results = assigns(:report_results)
        results.should have(2).things
        results.each {|r| r.name.should == 'base_report'}
      end

      it "should paginate results" do
        #add more reports
        21.times {|i| ReportResult.create(:name=>'base_report',:run_by_id=>@base_user.id)}
        get :index
        response.should be_success
        results = assigns(:report_results)
        results.should have(20).things
      end
      
      it "should sort results by run at date desc" do
        #make last report's run_at before first report's
        first_result = ReportResult.where(:run_by_id=>@base_user.id).last
        first_result.update_attributes(:run_at=>1.minutes.ago)
        last_result = ReportResult.where(:run_by_id=>@base_user.id).first
        last_result.update_attributes(:run_at=>5.minutes.ago)

        get :index
        response.should be_success
        results = assigns(:report_results)
        results.first.should == first_result
        results.last.should == last_result
      end
    end

    context 'admin' do
      
      before(:each) do
        UserSession.create @admin_user #log in
      end
      
      it "should show admin users only their reports when show all flag is not there" do
        get :index
        response.should be_success
        results = assigns(:report_results)
        results.should have(2).things
        results.each {|r| r.name.should == 'admin_report'}
      end
      
      it "should show admin users all reports when show all flag is turned on" do
        get :index, :show_all=>'true'
        response.should be_success
        results = assigns(:report_results)
        results.should have(4).things
      end
    end
  end

  describe 'show' do
    context 'admin' do
      before(:each) do
        UserSession.create @admin_user
      end

      it "should show report run by another user" do
        get :show, {:id=>@base_report.id}
        response.should be_success
        assigns(:report_result).should == @base_report
      end
      it "should show report run by admin user" do
        get :show, {:id=>@admin_report.id}
        response.should be_success
        assigns(:report_result).should == @admin_report
      end
    end

    context 'basic user' do
      before(:each) do
        UserSession.create @base_user
      end

      it "should show report run by base user" do
        get :show, {:id=>@base_report.id}
        response.should be_success
        assigns(:report_result).should == @base_report
      end
      it "should not show report run by another user" do
        get :show, {:id=>@admin_report.id}
        response.should redirect_to('/')
      end
    end
  end
end
