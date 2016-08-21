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
        expect(response).to be_success
      end
      it 'should run the report' do
        post :run_containers_released, {'arrival_date_start'=>'2012-01-01','arrival_end_date'=>'2012-01-02','customer_numbers'=>"A\nB"}
        expect(response).to redirect_to('/report_results')
        expect(ReportResult.all.size).to eq(1)
        rr = ReportResult.first
        expect(rr.name).to eq("Container Release Status")
        expect(flash[:notices]).to include("Your report has been scheduled. You'll receive a system message when it finishes.")
      end
    end
  end
  describe 'stale tariffs report' do
    context 'show' do
      it 'should render the page' do
        get :show_stale_tariffs
        expect(response).to be_success
      end
    end
    context 'run' do
      it 'should execute the report' do
        allow(ReportResult).to receive(:execute_report) #don't really run the report
        post :run_stale_tariffs
        expect(response).to redirect_to('/report_results')
        expect(flash[:notices]).to include("Your report has been scheduled. You'll receive a system message when it finishes.")

        found = ReportResult.find_by_name 'Stale Tariffs'
        expect(found.run_by).to eq(@u)
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
        expect(response).to be_success
        countries = assigns(:countries)
        expect(countries.size).to eq(2)
        expect(countries).not_to include(@excluded_country)
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
        allow_any_instance_of(ReportResult).to receive(:execute_report)
        old_ts = TariffSet.first
        new_ts = TariffSet.last

        post :run_tariff_comparison, {'old_tariff_set_id'=>old_ts.id.to_s,'new_tariff_set_id'=>new_ts.id.to_s}
        expect(response).to redirect_to('/report_results')
        expect(flash[:notices]).to include("Your report has been scheduled. You'll receive a system message when it finishes.")

        found = ReportResult.find_by_name 'Tariff Comparison'
        expect(found.run_by).to eq(@u)
        expect(found.friendly_settings).to eq(["Country: #{old_ts.country.name}","Old Tariff File: #{old_ts.label}","New Tariff File: #{new_ts.label}"])
        settings = ActiveSupport::JSON.decode found.settings_json
        expect(settings['old_tariff_set_id']).to eq(old_ts.id.to_s)
        expect(settings['new_tariff_set_id']).to eq(new_ts.id.to_s)
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
        expect(response).not_to be_success
      end

      it "should render page for admin users" do
        sign_in_as @admin
        expect(OpenChain::Report::HmStatisticsReport).to receive(:permission?).and_return true
        get :show_hm_statistics
        expect(response).to be_success
      end
    end

    context "run" do
      it "should not run the report for non-admin users" do
        post :run_hm_statistics
        expect(flash[:errors].first).to eq("You do not have permission to view this report.")
      end

      it "should run the report for admin users" do
        expect(OpenChain::Report::HmStatisticsReport).to receive(:permission?).and_return true
        post :run_hm_statistics, {'start_date'=>'2014-01-02','end_date'=>'2014-03-04'}
        expect(response).to be_redirect
        expect(flash[:notices].first).to eq("Your report has been scheduled. You'll receive a system message when it finishes.")
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
        expect(response).not_to be_success
      end

      it "should render page for admin user" do
        sign_in_as @admin
        get :show_poa_expirations
        expect(response).to be_success
      end
    end

    context "run as admin" do
      it "should run report for valid date and admin user" do
        sign_in_as @admin
        get :run_poa_expirations, {'poa_expiration_date' => '2012-01-20'}
        expect(response).to be_redirect
        expect(flash[:notices].first).to eq("Your report has been scheduled. You'll receive a system message when it finishes.")
      end
    end

    context "run as non-admin user" do
      it "should not execute report" do
        get :run_poa_expirations, {'poa_expiration_date' => '2012-01-20'}
        expect(flash[:errors].first).to eq("You do not have permissions to view this report")
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
        expect(ReportResult).to receive(:run_report!).with("Drawback Audit Report", @u, OpenChain::Report::DrawbackAuditReport, {:settings=>{:drawback_claim_id=>@dc.first.id.to_s}, :friendly_settings=>[]})
        put :run_drawback_audit_report, {drawback_claim_id: @dc.first.id}
        expect(response).to be_redirect
        expect(flash[:notices].first).to eq "Your report has been scheduled. You'll receive a system message when it finishes."
      end

      it "should not execute report for non-drawback user" do
        expect(ReportResult).not_to receive(:run_report!).with("Drawback Audit Report", @u, OpenChain::Report::DrawbackAuditReport, {:settings=>{:drawback_claim_id=>@dc.first.id.to_s}, :friendly_settings=>[]})
        put :run_drawback_audit_report, {drawback_claim_id: @dc.first.id}
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
        expect(ReportResult).to receive(:run_report!).with("Ralph Lauren Monthly Tariff Totals", @u, OpenChain::Report::RlTariffTotals, {:settings=>{time_zone: @u.time_zone, start_date: @start_date, end_date: @end_date}, :friendly_settings=>[]})
        post :run_rl_tariff_totals, {start_date: @start_date, end_date: @end_date}
        expect(response).to be_redirect
        expect(flash[:notices].first).to eq "Your report has been scheduled. You'll receive a system message when it finishes."
      end

      it "should not run report for non-RL user" do
        expect(ReportResult).not_to receive(:run_report!).with("Ralph Lauren Monthly Tariff Totals", @u, OpenChain::Report::RlTariffTotals, {:settings=>{time_zone: @u.time_zone, start_date: @start_date, end_date: @end_date}, :friendly_settings=>[]})
        post :run_rl_tariff_totals, {start_date: @start_date, end_date: @end_date}
        expect(response).to be_redirect
        expect(flash[:errors].first).to eq "You do not have permission to view this report"
      end
    end
  end

  describe "LL Product Risk Report" do
    context 'show' do
      it 'renders page for LL user' do
        MasterSetup.create!(system_code: 'll')
        @u = Factory(:master_user)
        allow(@u).to receive(:view_products?).and_return true
        sign_in_as @u

        get :show_ll_prod_risk_report
        expect(response).to be_success
      end

      it "doesn't render page for non-LL user" do
        get :show_ll_prod_risk_report
        expect(response).to_not be_success
      end
    end

    context 'run' do
      it 'runs report for LL user' do
        MasterSetup.create!(system_code: 'll')
        @u = Factory(:master_user)
        allow(@u).to receive(:view_products?).and_return true
        sign_in_as @u

        expect(ReportResult).to receive(:run_report!).with("Lumber Liquidators Product Risk Report", @u, OpenChain::Report::LlProdRiskReport, :settings=>{}, :friendly_settings=>[])
        post :run_ll_prod_risk_report
      end

      it "doesn't run report for non-LL user" do
        expect(ReportResult).not_to receive(:run_report!)
        post :run_ll_prod_risk_report
      end
    end
  end

  describe "PVH Billing Summary Report" do
    context "show" do
      it "renders page for Vandegrift user" do
        MasterSetup.create(system_code: 'www-vfitrack-net')
        @u = Factory(:master_user)
        allow(@u).to receive(:view_broker_invoices?).and_return true
        sign_in_as @u

        get :show_pvh_billing_summary
        expect(response).to be_success
      end

      it "doesn't render page for non-Vandegrift user" do
        get :show_pvh_billing_summary
        expect(response).to_not be_success
      end
    end

    context "run" do
      before(:each) do 
        MasterSetup.create(system_code: 'www-vfitrack-net')
        @invoice_numbers = "123456789 987654321 246810121" 
        @u = Factory(:master_user)
        allow(@u).to receive(:view_broker_invoices?).and_return true
        sign_in_as @u
      end

      it "runs report for Vandegrift user" do
        expect(ReportResult).to receive(:run_report!).with("PVH Billing Summary", @u, OpenChain::Report::PvhBillingSummary, {:settings => {:invoice_numbers => ['123456789', '987654321', '246810121']}, :friendly_settings=>[]})
        post :run_pvh_billing_summary, {invoice_numbers: @invoice_numbers}
        expect(response).to be_redirect
        expect(flash[:notices].first).to eq "Your report has been scheduled. You'll receive a system message when it finishes."
      end

      it "doesn't run report with missing invoice numbers" do
        expect(ReportResult).not_to receive(:run_report!)
        post :run_pvh_billing_summary, {invoice_numbers: " \n "}
        expect(response).to be_redirect
        expect(flash[:errors].first).to eq "Please enter at least one invoice number."
      end

      it "doesn't run report for non-Vandegrift user" do
        @u = Factory(:user)
        sign_in_as @u
        expect(ReportResult).not_to receive(:run_report!)
        post :run_pvh_billing_summary, {invoice_numbers: @invoice_numbers}
        expect(response).to be_redirect
        expect(flash[:errors].first).to eq "You do not have permission to view this report"
      end
    end
  end

  describe "SG Duty Due Report" do
    before :each do  
      MasterSetup.create(system_code: 'www-vfitrack-net')
      @u = Factory(:master_user)
      allow(@u).to receive(:view_entries?).and_return true
      sign_in_as @u
    end

    context "show" do
      it "doesn't render page for unauthorized users" do
        expect(OpenChain::Report::SgDutyDueReport).to receive(:permission?).and_return false
        get :show_sg_duty_due_report
        expect(response).not_to be_success
      end
      
      it "renders page for authorized users" do
        sgi = Factory(:company, name: 'SGI APPAREL LTD', alliance_customer_number: 'SGI')
        sgold = Factory(:company, name: 'S GOLDBERG & CO INC', alliance_customer_number: 'SGOLD')
        rugged = Factory(:company, name: 'RUGGED SHARK LLC', alliance_customer_number: 'RUGGED')
        Factory(:company)

        sign_in_as @u
        get :show_sg_duty_due_report
        expect(response).to be_success
        expect(assigns(:choices)).to eq [sgi, sgold, rugged]
      end
    end

    context "run" do
      it "doesn't run report for unauthorized users" do
        expect(OpenChain::Report::SgDutyDueReport).to receive(:permission?).and_return false
        expect(ReportResult).not_to receive(:run_report!)
        post :run_sg_duty_due_report, {customer_number: "SGOLD"}
        expect(flash[:errors].first).to eq "You do not have permission to view this report."
        expect(response).to be_redirect
      end

      it "runs report for authorized users" do
        expect(ReportResult).to receive(:run_report!).with("SG Duty Due Report", @u, OpenChain::Report::SgDutyDueReport, {:settings => {customer_number: 'SGOLD'}, :friendly_settings=>[]})
        post :run_sg_duty_due_report, {customer_number: "SGOLD"}
        expect(flash[:notices].first).to eq "Your report has been scheduled. You'll receive a system message when it finishes."
        expect(response).to be_redirect
      end
    end
  end

  describe "Eddie Bauer CA K84 Summary" do
    before :each do
      MasterSetup.create!(system_code: 'www-vfitrack-net')
      @u = Factory(:master_user)
      allow(@u).to receive(:view_commercial_invoices?).and_return true
      sign_in_as @u

      @date = Date.today
    end

    context "show" do
      it "renders page for Vandegrift user" do
        get :show_eddie_bauer_ca_k84_summary
        expect(response).to be_success
      end

      it "doesn't render page for non-Vandegrift user" do
        @u = Factory(:user)
        sign_in_as @u
        get :show_eddie_bauer_ca_k84_summary
        expect(response).to_not be_success
      end
    end

    context "run" do

      it "runs report for Vandegrift user" do
        expect(ReportResult).to receive(:run_report!).with("Eddie Bauer CA K84 Summary", @u, OpenChain::Report::EddieBauerCaK84Summary, {settings: {date: @date}, friendly_settings: []})
        post :run_eddie_bauer_ca_k84_summary, {date: @date}
        expect(response).to be_redirect
        expect(flash[:notices].first).to eq "Your report has been scheduled. You'll receive a system message when it finishes."
      end

      it "doesn't run report for non-Vandegrift user" do
        @u = Factory(:user)
        sign_in_as @u
        expect(ReportResult).not_to receive(:run_report!)
        post :run_eddie_bauer_ca_k84_summary, {date: @date}
        
        expect(response).to be_redirect
        expect(flash[:errors].first).to eq "You do not have permission to view this report"
      end

      it "doesn't run report with missing date range" do
        expect(ReportResult).not_to receive(:run_report!)
        post :run_eddie_bauer_ca_k84_summary, {date: ""}
        
        expect(response).to be_redirect
        expect(flash[:errors].first).to eq "Please enter a K84 due date."
      end

    end

  end

end
