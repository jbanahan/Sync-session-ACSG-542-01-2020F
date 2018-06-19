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
    let(:report_class) { OpenChain::Report::StaleTariffs }
    before do
      @ms = stub_master_setup
      allow(@ms).to receive(:custom_feature?).with("WWW VFI Track Reports").and_return true
    end
    
    context 'show' do
      it 'renders the page for authorized users' do
        expect(report_class).to receive(:permission?).with(@u).and_return true
        get :show_stale_tariffs
        expect(response).to be_success
        expect(assigns(:customer_number_selector)).to eq true
      end

      it "renders without customer-number selector for other instances" do
        expect(report_class).to receive(:permission?).with(@u).and_return true
        allow(@ms).to receive(:custom_feature?).with("WWW VFI Track Reports").and_return false
        get :show_stale_tariffs
        expect(response).to be_success
        expect(assigns(:customer_number_selector)).to be_nil
      end

      it "rejects unauthorized users" do
        expect(report_class).to receive(:permission?).with(@u).and_return false
        get :show_stale_tariffs
        expect(response).to be_redirect
        expect(flash[:errors].first).to eq "You do not have permission to view this report."
      end
    end
    context 'run' do
      it 'executes the report for authorized users' do
        expect(report_class).to receive(:permission?).with(@u).and_return(true)
        expect(ReportResult).to receive(:run_report!).with("Stale Tariffs", @u, OpenChain::Report::StaleTariffs, :settings=>{"customer_numbers"=>"code1\ncode2"}, :friendly_settings=>[])
        
        post :run_stale_tariffs, {"customer_numbers"=>"code1\ncode2"}
        expect(response).to redirect_to('/report_results')
        expect(flash[:notices]).to include("Your report has been scheduled. You'll receive a system message when it finishes.")
      end

      it 'executes the report without customer-number parameter for other instances' do
        allow(@ms).to receive(:custom_feature?).with("WWW VFI Track Reports").and_return false
        expect(report_class).to receive(:permission?).with(@u).and_return(true)
        expect(ReportResult).to receive(:run_report!).with("Stale Tariffs", @u, OpenChain::Report::StaleTariffs, :settings=>{"customer_numbers"=>nil}, :friendly_settings=>[])
        
        post :run_stale_tariffs, {"customer_numbers"=>"code1\ncode2"}
        expect(response).to redirect_to('/report_results')
        expect(flash[:notices]).to include("Your report has been scheduled. You'll receive a system message when it finishes.")
      end

      it "rejects unauthorized users" do
        expect(report_class).to receive(:permission?).with(@u).and_return(false)
        expect(ReportResult).to_not receive(:execute_report)
        
        post :run_stale_tariffs
        expect(flash[:errors].first).to eq "You do not have permission to view this report."
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

    context "run", :disable_delayed_jobs do
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

  describe "Daily First Sale Exception Report" do
    let(:report_class) { OpenChain::Report::DailyFirstSaleExceptionReport }
    let(:user) { Factory(:user) }
    before { sign_in_as user}
    
    context "show" do
      it "doesn't render page for unauthorized users" do
        expect(report_class).to receive(:permission?).with(user).and_return false
        get :show_daily_first_sale_exception_report
        expect(response).not_to be_success
      end

      it "renders for authorized users" do
        expect(report_class).to receive(:permission?).with(user).and_return true
        get :show_daily_first_sale_exception_report
        expect(response).to be_success
      end
    end

    context "run" do
      it "doesn't run for unauthorized users" do
        expect(report_class).to receive(:permission?).with(user).and_return false
        expect(ReportResult).not_to receive(:run_report!)
        post :run_daily_first_sale_exception_report
        expect(flash[:errors].first).to eq("You do not have permission to view this report.")
      end

      it "runs for authorized users" do
        expect(report_class).to receive(:permission?).with(user).and_return true
        expect(ReportResult).to receive(:run_report!).with("Daily First Sale Exception Report", user, OpenChain::Report::DailyFirstSaleExceptionReport, :settings=>{}, :friendly_settings=>[])
        post :run_daily_first_sale_exception_report
        expect(response).to be_redirect
        expect(flash[:notices].first).to eq("Your report has been scheduled. You'll receive a system message when it finishes.")
      end
    end
  end

  describe "Duty Savings Report" do
    context "show" do
      it "doesn't render page for users who don't have permission" do
        get :show_duty_savings_report
        expect(response).not_to be_success
      end

      it "renders for users who have permission" do
        u = Factory(:master_user)
        sign_in_as u
        expect(u).to receive(:view_entries?).and_return true
        get :show_duty_savings_report
        expect(response).to be_success
      end
    end

    context "run" do
      let(:settings) { {"start_date" => "2016-01-01", "end_date" => "2016-02-01", "customer_numbers" => "ACME,\nKonvenientz; \nFoodMarmot"} }
      
      it "doesn't run for users who don't have permission" do
        post :run_duty_savings_report, settings
        expect(flash[:errors].first).to eq("You do not have permission to view this report.")
      end

      it "runs for users who have permission" do
        u = Factory(:master_user)
        sign_in_as u
        expect(u).to receive(:view_entries?).and_return true
        post :run_duty_savings_report, settings
        expect(response).to be_redirect
        expect(flash[:notices].first).to eq("Your report has been scheduled. You'll receive a system message when it finishes.")
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

  describe "Ticket Tracking Report" do
    let(:report_class) { OpenChain::Report::TicketTrackingReport }
    let(:user) { Factory(:user) }
    before { sign_in_as user }

    context "show" do
      it "doesn't render page for unauthorized users" do
        expect(report_class).to receive(:permission?).with(user).and_return false
        get :show_ticket_tracking_report
        expect(response).not_to be_success
      end

      it "renders for authorized users" do
        co = user.company
        co.update_attributes(ticketing_system_code: "FOO")
        expect(report_class).to receive(:permission?).with(user).and_return true
        get :show_ticket_tracking_report
        expect(response).to be_success
        expect(assigns(:project_keys)).to eq ["FOO"]
      end
    end

    context "run" do
      it "doesn't run for unauthorized users" do
        expect(report_class).to receive(:permission?).with(user).and_return false
        expect(ReportResult).not_to receive(:run_report!)
        post :run_ticket_tracking_report, start_date: "start", end_date: "end", project_keys: ["CODES"]
        expect(flash[:errors].first).to eq("You do not have permission to view this report")
      end

      it "runs for authorized users" do
        expect(report_class).to receive(:permission?).with(user).and_return true
        expect(ReportResult).to receive(:run_report!).with("Ticket Tracking Report", user, OpenChain::Report::TicketTrackingReport, :settings=>{start_date: "start", end_date: "end", project_keys: ["CODES"]}, :friendly_settings=>[])
        post :run_ticket_tracking_report, start_date: "start", end_date: "end", project_keys: ["CODES"]
        expect(response).to be_redirect
        expect(flash[:notices].first).to eq("Your report has been scheduled. You'll receive a system message when it finishes.")
      end
    end
  end

  describe "Ascena Actual Vs Potential First Sale Report" do
    let(:report_class) { OpenChain::Report::AscenaActualVsPotentialFirstSaleReport }
    let(:user) { Factory(:user) }
    before { sign_in_as user }

    context "show" do
      it "doesn't render page for unauthorized users" do
        expect(report_class).to receive(:permission?).with(user).and_return false
        get :show_ascena_actual_vs_potential_first_sale_report
        expect(response).not_to be_success
      end

      it "renders for authorized users" do
        expect(report_class).to receive(:permission?).with(user).and_return true
        get :show_ascena_actual_vs_potential_first_sale_report
        expect(response).to be_success
      end
    end

    context "run" do
      it "doesn't run for unauthorized users" do
        expect(report_class).to receive(:permission?).with(user).and_return false
        expect(ReportResult).not_to receive(:run_report!)
        post :show_ascena_actual_vs_potential_first_sale_report
        expect(flash[:errors].first).to eq("You do not have permission to view this report")
      end

      it "runs for authorized users" do
        expect(report_class).to receive(:permission?).with(user).and_return true
        expect(ReportResult).to receive(:run_report!).with("Ascena Actual vs Potential First Sale Report", user, report_class, 
                                                           :settings=>{}, :friendly_settings=>[])
        post :run_ascena_actual_vs_potential_first_sale_report
        expect(response).to be_redirect
        expect(flash[:notices].first).to eq("Your report has been scheduled. You'll receive a system message when it finishes.")
      end
    end
  end

  describe "Ascena Entry Audit Report" do
    let(:report_class) { OpenChain::Report::AscenaEntryAuditReport }
    let(:user) { Factory(:user) }
    before { sign_in_as user }

    context "show" do
      it "doesn't render page for unauthorized users" do
        expect(report_class).to receive(:permission?).with(user).and_return false
        get :show_ascena_entry_audit_report
        expect(response).not_to be_success
      end

      it "renders for authorized users" do
        expect(report_class).to receive(:permission?).with(user).and_return true
        get :show_ascena_entry_audit_report
        expect(response).to be_success
      end
    end

    context "run" do
      let(:args) { {range_field: "release_date", start_release_date: "start release", end_release_date: "end release", start_fiscal_year_month: "start fy/m", 
                    end_fiscal_year_month: "end fy/m", run_as_company: "company" }}
      
      it "doesn't run for unauthorized users" do
        expect(report_class).to receive(:permission?).with(user).and_return false
        expect(ReportResult).not_to receive(:run_report!)
        post :run_ascena_entry_audit_report, args
        expect(flash[:errors].first).to eq("You do not have permission to view this report")
      end

      it "runs for authorized users" do
        expect(report_class).to receive(:permission?).with(user).and_return true
        expect(ReportResult).to receive(:run_report!).with("Ascena Entry Audit Report", user, OpenChain::Report::AscenaEntryAuditReport, 
                                                           :settings=>args, :friendly_settings=>[])
        post :run_ascena_entry_audit_report, args
        expect(response).to be_redirect
        expect(flash[:notices].first).to eq("Your report has been scheduled. You'll receive a system message when it finishes.")
      end
    end
  end

  describe "Ascena Vendor Scorecard Report" do
    let(:report_class) { OpenChain::CustomHandler::Ascena::AscenaVendorScorecardReport }
    let(:user) { Factory(:user) }
    before { sign_in_as user }

    context "show" do
      it "doesn't render page for unauthorized users" do
        expect(report_class).to receive(:permission?).with(user).and_return false
        get :show_ascena_vendor_scorecard_report
        expect(response).not_to be_success
      end

      it "renders for authorized users" do
        expect(report_class).to receive(:permission?).with(user).and_return true
        get :show_ascena_vendor_scorecard_report
        expect(response).to be_success
      end
    end

    context "run" do
      let(:args) { {range_field: "first_release_date", start_release_date: "start release", end_release_date: "end release", start_fiscal_year_month: "start fy/m",
                    end_fiscal_year_month: "end fy/m"}}

      it "doesn't run for unauthorized users" do
        expect(report_class).to receive(:permission?).with(user).and_return false
        expect(ReportResult).not_to receive(:run_report!)
        post :run_ascena_vendor_scorecard_report, args
        expect(flash[:errors].first).to eq("You do not have permission to view this report")
      end

      it "runs for authorized users" do
        expect(report_class).to receive(:permission?).with(user).and_return true
        expect(ReportResult).to receive(:run_report!).with("Ascena Vendor Scorecard Report", user, OpenChain::CustomHandler::Ascena::AscenaVendorScorecardReport,
                                                           :settings=>args, :friendly_settings=>[])
        post :run_ascena_vendor_scorecard_report, args
        expect(response).to be_redirect
        expect(flash[:notices].first).to eq("Your report has been scheduled. You'll receive a system message when it finishes.")
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

  describe "Entry Year Over Year Report" do
    let(:report_class) { OpenChain::Report::CustomerYearOverYearReport }
    let(:user) { Factory(:user) }
    before { sign_in_as user }

    context "show" do
      it "doesn't render page for unauthorized users" do
        expect(report_class).to receive(:permission?).with(user).and_return false
        get :show_customer_year_over_year_report
        expect(response).not_to be_success
      end

      it "renders for authorized users, master user" do
        user.company.master = true
        user.save!

        us_company_1 = Factory(:company, name:'US-Z', alliance_customer_number:'12345', fenix_customer_number:'', importer:true)
        us_company_2 = Factory(:company, name:'US-A', alliance_customer_number:'23456', importer:true)
        ca_company_1 = Factory(:company, name:'CA-Z', alliance_customer_number:'', fenix_customer_number:'12345', importer:true)
        ca_company_2 = Factory(:company, name:'CA-A', fenix_customer_number:'23456', importer:true)

        expect(report_class).to receive(:permission?).with(user).and_return true
        get :show_customer_year_over_year_report
        expect(response).to be_success

        # Ensure importer instance variables, used for dropdowns, were loaded properly.
        us_importers = subject.instance_variable_get(:@us_importers)
        expect(us_importers.length).to eq 2
        expect(us_importers[0].name).to eq('US-A')
        expect(us_importers[1].name).to eq('US-Z')

        ca_importers = subject.instance_variable_get(:@ca_importers)
        expect(ca_importers.length).to eq 2
        expect(ca_importers[0].name).to eq('CA-A')
        expect(ca_importers[1].name).to eq('CA-Z')
      end

      it "renders for authorized users, typical user" do
        us_company_1 = Factory(:company, name:'US-A', alliance_customer_number:'23456', fenix_customer_number:'', importer:true)

        user.company.customer = true
        user.company.linked_companies << us_company_1
        user.save!

        us_company_2 = Factory(:company, name:'US-Z', alliance_customer_number:'12345', fenix_customer_number:'', importer:true)
        ca_company = Factory(:company, name:'CA-Z', alliance_customer_number:'', fenix_customer_number:'12345', importer:true)

        expect(report_class).to receive(:permission?).with(user).and_return true
        get :show_customer_year_over_year_report
        expect(response).to be_success

        # Ensure importer instance variables, used for dropdowns, were loaded properly.
        us_importers = subject.instance_variable_get(:@us_importers)
        expect(us_importers.length).to eq 1
        expect(us_importers[0].name).to eq('US-A')

        expect(subject.instance_variable_get(:@ca_importers).length).to eq 0
      end
    end

    context "run" do
      it "doesn't run for unauthorized users" do
        expect(report_class).to receive(:permission?).with(user).and_return false
        expect(ReportResult).not_to receive(:run_report!)
        post :run_customer_year_over_year_report, {}
        expect(response).to be_redirect
        expect(flash[:errors].first).to eq("You do not have permission to view this report")
        expect(flash[:notices]).to be_nil
      end

      it "runs for authorized users, US importer" do
        expect(report_class).to receive(:permission?).with(user).and_return true
        expect(ReportResult).to receive(:run_report!).with("Entry Year Over Year Report", user, OpenChain::Report::CustomerYearOverYearReport,
                                          :settings=>{range_field:'some_date', importer_ids:[5], year_1:'2015', year_2:'2017',
                                                      include_cotton_fee:true, include_taxes:false, include_other_fees:false,
                                                      mode_of_transport:['Sea']}, :friendly_settings=>[])
        post :run_customer_year_over_year_report, {range_field:'some_date', country:'US', importer_id_us:['5'], importer_id_ca:['6'],
                                          year_1:'2015', year_2: '2017', cotton_fee:'true', taxes:'false', other_fees:nil,
                                          mode_of_transport:['Sea']}
        expect(response).to be_redirect
        expect(flash[:notices].first).to eq("Your report has been scheduled. You'll receive a system message when it finishes.")
      end

      it "runs for authorized users, CA importer" do
        expect(report_class).to receive(:permission?).with(user).and_return true
        expect(ReportResult).to receive(:run_report!).with("Entry Year Over Year Report", user, OpenChain::Report::CustomerYearOverYearReport,
                                         :settings=>{range_field:'some_date', importer_ids:[6,7], year_1:'2015', year_2:'2017',
                                                     include_cotton_fee:false, include_taxes:true, include_other_fees:true,
                                                     mode_of_transport:['Sea']}, :friendly_settings=>[])
        post :run_customer_year_over_year_report, {range_field:'some_date', country:'CA', importer_id_us:['5'], importer_id_ca:['6','7'],
                                          year_1:'2015', year_2: '2017', cotton_fee:'false', taxes:'true', other_fees:'true',
                                          mode_of_transport:['Sea']}
        expect(response).to be_redirect
        expect(flash[:notices].first).to eq("Your report has been scheduled. You'll receive a system message when it finishes.")
      end

      it "fails if importer is not selected (US)" do
        expect(report_class).to receive(:permission?).with(user).and_return true
        expect(ReportResult).not_to receive(:run_report!)
        post :run_customer_year_over_year_report, {range_field:'some_date', country:'US', importer_id_us:[], importer_id_ca:['6'],
                                          year_1:'2015', year_2: '2017'}
        expect(response).to be_redirect
        expect(flash[:errors].first).to eq("At least one importer must be selected.")
        expect(flash[:notices]).to be_nil
      end

      it "fails if importer is not selected (CA)" do
        expect(report_class).to receive(:permission?).with(user).and_return true
        expect(ReportResult).not_to receive(:run_report!)
        post :run_customer_year_over_year_report, {range_field:'some_date', country:'CA', importer_id_us:['5'], importer_id_ca:nil,
                                          year_1:'2015', year_2: '2017'}
        expect(response).to be_redirect
        expect(flash[:errors].first).to eq("At least one importer must be selected.")
        expect(flash[:notices]).to be_nil
      end
    end
  end

end
