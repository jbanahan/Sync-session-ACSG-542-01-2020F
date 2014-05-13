require 'spec_helper'

describe ReportResultsController do
  
  before(:each) do
    c = Company.create!(:name=>'btestc')
    @base_user = Factory(:user)
    @admin_user = Factory(:sys_admin_user)
    2.times do |i|
      @base_report = ReportResult.create!(:name=>'base_report',:run_by_id=>@base_user.id)
      @admin_report = ReportResult.create!(:name=>'admin_report',:run_by_id=>@admin_user.id)
    end

  end
  
  describe 'index' do

    context 'non-admin user' do
      before(:each) do
        sign_in_as @base_user #log in
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

      it "should show customizable reports if user can view them" do
        CustomReportEntryInvoiceBreakdown.stub(:can_view?).with(@base_user).and_return(true)
        CustomReportBillingAllocationByValue.stub(:can_view?).with(@base_user).and_return(true)
        CustomReportBillingStatementByPo.stub(:can_view?).with(@base_user).and_return(true)

        get :index
        response.should be_success
        custom_reports = assigns(:customizable_reports)
        custom_reports.should have(3).elements
      end
    end

    context 'admin' do
      
      before(:each) do
        sign_in_as @admin_user #log in
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
        sign_in_as @admin_user
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
        sign_in_as @base_user
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
