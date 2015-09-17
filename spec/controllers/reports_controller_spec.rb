require 'spec_helper'

describe ReportsController do

  before(:each) do
    @u = Factory(:user)

    sign_in_as @u
  end

  describe 'containers released report' do
    context 'show' do
      it 'should render the page' do
        get :show_containers_released
        response.should be_success
      end
      it 'should run the report' do
        post :run_containers_released, {'arrival_date_start'=>'2012-01-01','arrival_date_end'=>'2012-01-02','customer_numbers'=>"A\nB"}
        response.should redirect_to('/report_results')
        ReportResult.all.should have(1).item
        rr = ReportResult.first
        rr.name.should == "Container Release Status"
        flash[:notices].should include("Your report has been scheduled. You'll receive a system message when it finishes.")
      end
    end
  end
  describe 'stale tariffs report' do
    context 'show' do
      it 'should render the page' do
        get :show_stale_tariffs
        response.should be_success
      end
    end
    context 'run' do
      it 'should execute the report' do
        ReportResult.stub(:execute_report) #don't really run the report
        post :run_stale_tariffs
        response.should redirect_to('/report_results')
        flash[:notices].should include("Your report has been scheduled. You'll receive a system message when it finishes.")

        found = ReportResult.find_by_name 'Stale Tariffs'
        found.run_by.should == @u
      end
    end
  end

  describe 'tariff comparison report' do
    before(:each) do
      Country.destroy_all
      2.times do |i| 
        c = Factory(:country)
        c.tariff_sets.create(:label=>"t#{i}")
      end
      @excluded_country = Factory(:country)
    end

    context "show" do
      it "should set all countries with tariffs" do
        get :show_tariff_comparison
        response.should be_success
        countries = assigns(:countries)
        countries.should have(2).things
        countries.should_not include(@excluded_country)
      end
    end

    context "run" do
      before(:each) do
        Delayed::Worker.delay_jobs = false
      end
      after :each do
        Delayed::Worker.delay_jobs = true
      end
      it "should call report with tariff ids in settings" do
        ReportResult.any_instance.stub(:execute_report)
        old_ts = TariffSet.first
        new_ts = TariffSet.last

        post :run_tariff_comparison, {'old_tariff_set_id'=>old_ts.id.to_s,'new_tariff_set_id'=>new_ts.id.to_s}
        response.should redirect_to('/report_results')
        flash[:notices].should include("Your report has been scheduled. You'll receive a system message when it finishes.")

        found = ReportResult.find_by_name 'Tariff Comparison'
        found.run_by.should == @u
        found.friendly_settings.should == ["Country: #{old_ts.country.name}","Old Tariff File: #{old_ts.label}","New Tariff File: #{new_ts.label}"]
        settings = ActiveSupport::JSON.decode found.settings_json
        settings['old_tariff_set_id'].should == old_ts.id.to_s
        settings['new_tariff_set_id'].should == new_ts.id.to_s
      end
    end
  end

  describe "H&M Statistics Report" do
    before (:each) do
      @admin = Factory(:user)
      @admin.admin = true
      @admin.save
    end

    context "show" do
      it "should not render the page for non-admin users" do
        get :show_hm_statistics
        response.should_not be_success
      end

      it "should render page for admin users" do
        sign_in_as @admin
        OpenChain::Report::HmStatisticsReport.should_receive(:permission?).and_return true
        get :show_hm_statistics
        response.should be_success
      end
    end

    context "run" do
      it "should not run the report for non-admin users" do
        post :run_hm_statistics
        flash[:errors].first.should == "You do not have permission to view this report."
      end

      it "should run the report for admin users" do
        OpenChain::Report::HmStatisticsReport.should_receive(:permission?).and_return true
        post :run_hm_statistics, {'start_date'=>'2014-01-02','end_date'=>'2014-03-04'}
        response.should be_redirect
        flash[:notices].first.should == "Your report has been scheduled. You'll receive a system message when it finishes."
      end
      
    end
  end

  describe "POA expiration report" do
    before(:each) do
      @admin = Factory(:user)
      @admin.admin = true
      @admin.save
    end
    
    context "show" do
      it "should not render page for non-admin user" do
        get :show_poa_expirations
        response.should_not be_success
      end

      it "should render page for admin user" do
        sign_in_as @admin
        get :show_poa_expirations
        response.should be_success
      end
    end

    context "run as admin" do
      it "should run report for valid date and admin user" do
        sign_in_as @admin
        get :run_poa_expirations, {'poa_expiration_date' => '2012-01-20'}
        response.should be_redirect
        flash[:notices].first.should == "Your report has been scheduled. You'll receive a system message when it finishes."
      end
    end

    context "run as non-admin user" do
      it "should not execute report" do
        get :run_poa_expirations, {'poa_expiration_date' => '2012-01-20'}
        flash[:errors].first.should == "You do not have permissions to view this report"
      end
    end
  end

  describe "Drawback audit report" do
    before(:each) do
      @u = Factory(:drawback_user)
      @u.company.drawback_claims << Factory(:drawback_claim)
      @dc = @u.company.drawback_claims
    end

    context "show" do
      it "should render page for drawback user" do
        sign_in_as @u
        get :show_drawback_audit_report
        expect(assigns(:claims).count).to eq 1
        expect(response).to be_success
      end

      it "should not render page for non-drawback user" do
        get :show_drawback_audit_report
        expect(response).to_not be_success
      end
    end

    context "run" do
      it "should run report for drawback user" do
        sign_in_as @u
        ReportResult.should_receive(:run_report!).with("Drawback Audit Report", @u, OpenChain::Report::DrawbackAuditReport, {:settings=>{:drawback_claim_id=>@dc.first.id.to_s}, :friendly_settings=>[]})
        get :run_drawback_audit_report, {drawback_claim_id: @dc.first.id}
        expect(response).to be_redirect
        expect(flash[:notices].first).to eq "Your report has been scheduled. You'll receive a system message when it finishes."
      end

      it "should not execute report for non-drawback user" do
        ReportResult.should_not_receive(:run_report!).with("Drawback Audit Report", @u, OpenChain::Report::DrawbackAuditReport, {:settings=>{:drawback_claim_id=>@dc.first.id.to_s}, :friendly_settings=>[]})
        get :run_drawback_audit_report, {drawback_claim_id: @dc.first.id}
        expect(response).to be_redirect
        expect(flash[:errors].first).to eq "You do not have permission to view this report"
      end
    end
  end

  describe "RL Monthly Tariff Totals" do
    context "show" do
      it "should render page for Polo user" do
        MasterSetup.create(system_code: 'polo')
        @u = Factory(:master_user, product_view: true, time_zone: "Hawaii")
        sign_in_as @u

        get :show_rl_tariff_totals
        expect(response).to be_success
      end

      it "should not render page for non-Polo user" do
        get :show_rl_tariff_totals
        expect(response).to_not be_success
      end
    end

    context "run" do
      before(:each) do
        @start_date = Date.today.to_s
        @end_date = (Date.today + 1).to_s
      end

      it "should run report for RL user" do
        MasterSetup.create(system_code: 'polo')
        @u = Factory(:master_user, product_view: true)
        sign_in_as @u
        ReportResult.should_receive(:run_report!).with("Ralph Lauren Monthly Tariff Totals", @u, OpenChain::Report::RlTariffTotals, {:settings=>{time_zone: @u.time_zone, start_date: @start_date, end_date: @end_date}, :friendly_settings=>[]})
        post :run_rl_tariff_totals, {start_date: @start_date, end_date: @end_date}
        expect(response).to be_redirect
        expect(flash[:notices].first).to eq "Your report has been scheduled. You'll receive a system message when it finishes."
      end

      it "should not run report for non-RL user" do
        ReportResult.should_not_receive(:run_report!).with("Ralph Lauren Monthly Tariff Totals", @u, OpenChain::Report::RlTariffTotals, {:settings=>{time_zone: @u.time_zone, start_date: @start_date, end_date: @end_date}, :friendly_settings=>[]})
        post :run_rl_tariff_totals, {start_date: @start_date, end_date: @end_date}
        expect(response).to be_redirect
        expect(flash[:errors].first).to eq "You do not have permission to view this report"
      end
    end
  end

end
