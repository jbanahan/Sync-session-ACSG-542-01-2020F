describe ReportsController do

  let! (:master_setup) { stub_master_setup }

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
        post :run_containers_released, {'arrival_date_start'=>'2012-01-01', 'arrival_date_end'=>'2012-01-02', 'customer_numbers'=>"A\nB"}
        expect(response).to redirect_to('/report_results')
        expect(ReportResult.all.size).to eq(1)
        rr = ReportResult.first
        expect(rr.name).to eq("Container Release Status")
        expect(flash[:notices]).to include("Your report has been scheduled. You'll receive a system message when it finishes.")
      end
      it "requires dates to run" do
        post :run_containers_released, {'customer_numbers'=>"A\nB"}
        expect(response).to redirect_to request.referrer
        expect(ReportResult.all.size).to eq(0)
        expect(flash[:errors].first).to eq "Start and end dates are required."
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
        expect_any_instance_of(ReportResult).to_not receive(:execute_report)

        post :run_stale_tariffs
        expect(flash[:errors].first).to eq "You do not have permission to view this report."
      end
    end
  end

  describe 'tariff comparison report' do
    context "show" do
      it "should set all countries with tariffs" do
        c = Country.new
        c2 = Country.new
        expect(OpenChain::Report::TariffComparison).to receive(:available_countries).and_return [c, c2]
        get :show_tariff_comparison
        expect(response).to be_success

        expect(assigns(:countries)).to eq [c, c2]
      end
    end

    context "run", :disable_delayed_jobs do
      let (:country) { Factory(:country) }
      let (:first_tariff_set) { country.tariff_sets.create! label: "Old" }
      let (:second_tariff_set) { country.tariff_sets.create! label: "New" }

      it "should call report with tariff ids in settings" do
        allow_any_instance_of(ReportResult).to receive(:execute_report)

        post :run_tariff_comparison, {'old_tariff_set_id'=>first_tariff_set.id.to_s, 'new_tariff_set_id'=>second_tariff_set.id.to_s}
        expect(response).to redirect_to('/report_results')
        expect(flash[:notices]).to include("Your report has been scheduled. You'll receive a system message when it finishes.")

        found = ReportResult.find_by(name: 'Tariff Comparison')
        expect(found.run_by).to eq(@u)
        expect(found.friendly_settings).to eq(["Country: #{first_tariff_set.country.name}", "Old Tariff File: #{first_tariff_set.label}", "New Tariff File: #{second_tariff_set.label}"])
        settings = ActiveSupport::JSON.decode found.settings_json
        expect(settings['old_tariff_set_id']).to eq(first_tariff_set.id.to_s)
        expect(settings['new_tariff_set_id']).to eq(second_tariff_set.id.to_s)
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
        post :run_hm_statistics, {'start_date'=>'2014-01-02', 'end_date'=>'2014-03-04'}
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
        expect(OpenChain::Report::RlTariffTotals).to receive(:permission?).with(@u).and_return true
        get :show_rl_tariff_totals
        expect(response).to be_success
      end

      it "should not render page for non-Polo user" do
        expect(OpenChain::Report::RlTariffTotals).to receive(:permission?).with(@u).and_return false
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
        expect(OpenChain::Report::RlTariffTotals).to receive(:permission?).with(@u).and_return true
        expect(ReportResult).to receive(:run_report!).with("Ralph Lauren Monthly Tariff Totals", @u, OpenChain::Report::RlTariffTotals, {:settings=>{time_zone: @u.time_zone, start_date: @start_date, end_date: @end_date}, :friendly_settings=>[]})
        post :run_rl_tariff_totals, {start_date: @start_date, end_date: @end_date}
        expect(response).to be_redirect
        expect(flash[:notices].first).to eq "Your report has been scheduled. You'll receive a system message when it finishes."
      end

      it "should not run report for non-RL user" do
        expect(OpenChain::Report::RlTariffTotals).to receive(:permission?).with(@u).and_return false
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
        expect(OpenChain::Report::LlProdRiskReport).to receive(:permission?).with(@u).and_return true
        get :show_ll_prod_risk_report
        expect(response).to be_success
      end

      it "doesn't render page for non-LL user" do
        expect(OpenChain::Report::LlProdRiskReport).to receive(:permission?).with(@u).and_return false
        get :show_ll_prod_risk_report
        expect(response).to_not be_success
      end
    end

    context 'run' do
      it 'runs report for LL user' do
        expect(OpenChain::Report::LlProdRiskReport).to receive(:permission?).with(@u).and_return true
        expect(ReportResult).to receive(:run_report!).with("Lumber Liquidators Product Risk Report", @u, OpenChain::Report::LlProdRiskReport, :settings=>{}, :friendly_settings=>[])
        post :run_ll_prod_risk_report
      end

      it "doesn't run report for non-LL user" do
        expect(OpenChain::Report::LlProdRiskReport).to receive(:permission?).with(@u).and_return false
        expect(ReportResult).not_to receive(:run_report!)
        post :run_ll_prod_risk_report
      end
    end
  end

  describe "PVH Billing Summary Report" do
    context "show" do
      it "renders page for Vandegrift user" do
        expect(OpenChain::Report::PvhBillingSummary).to receive(:permission?).with(@u).and_return true

        get :show_pvh_billing_summary
        expect(response).to be_success
      end

      it "doesn't render page for non-Vandegrift user" do
        expect(OpenChain::Report::PvhBillingSummary).to receive(:permission?).with(@u).and_return false
        get :show_pvh_billing_summary
        expect(response).to_not be_success
      end
    end

    context "run" do
      let (:invoice_numbers) { "123456789 987654321 246810121" }

      it "runs report for Vandegrift user" do
        expect(OpenChain::Report::PvhBillingSummary).to receive(:permission?).with(@u).and_return true
        expect(ReportResult).to receive(:run_report!).with("PVH Billing Summary", @u, OpenChain::Report::PvhBillingSummary, {:settings => {:invoice_numbers => ['123456789', '987654321', '246810121']}, :friendly_settings=>[]})
        post :run_pvh_billing_summary, {invoice_numbers: invoice_numbers}
        expect(response).to be_redirect
        expect(flash[:notices].first).to eq "Your report has been scheduled. You'll receive a system message when it finishes."
      end

      it "doesn't run report with missing invoice numbers" do
        expect(OpenChain::Report::PvhBillingSummary).to receive(:permission?).with(@u).and_return true
        expect(ReportResult).not_to receive(:run_report!)
        post :run_pvh_billing_summary, {invoice_numbers: " \n "}
        expect(response).to be_redirect
        expect(flash[:errors].first).to eq "Please enter at least one invoice number."
      end

      it "doesn't run report for non-Vandegrift user" do
        expect(OpenChain::Report::PvhBillingSummary).to receive(:permission?).with(@u).and_return false
        expect(ReportResult).not_to receive(:run_report!)
        post :run_pvh_billing_summary, {invoice_numbers: invoice_numbers}
        expect(response).to be_redirect
        expect(flash[:errors].first).to eq "You do not have permission to view this report"
      end
    end
  end

  describe "SG Duty Due Report" do

    context "show" do
      it "doesn't render page for unauthorized users" do
        expect(OpenChain::Report::SgDutyDueReport).to receive(:permission?).with(@u).and_return false
        get :show_sg_duty_due_report
        expect(response).not_to be_success
      end

      it "renders page for authorized users" do
        expect(OpenChain::Report::SgDutyDueReport).to receive(:permission?).with(@u).and_return true
        sgi = with_customs_management_id(Factory(:company, name: 'SGI APPAREL LTD'), 'SGI')
        sgold = with_customs_management_id(Factory(:company, name: 'S GOLDBERG & CO INC'), 'SGOLD')
        rugged = with_customs_management_id(Factory(:company, name: 'RUGGED SHARK LLC'), 'RUGGED')
        Factory(:company)

        get :show_sg_duty_due_report
        expect(response).to be_success
        choices = assigns(:choices).to_a
        expect(choices).to include sgi
        expect(choices).to include sgold
        expect(choices).to include rugged
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
        expect(OpenChain::Report::SgDutyDueReport).to receive(:permission?).and_return true
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
    let!(:user) { Factory(:user) }
    let!(:ascena) do
      co = Factory(:importer)
      co.set_system_identifier "Customs Management", "ASCE"
      co
    end

    before { sign_in_as user }

    context "show" do
      it "doesn't render page for unauthorized users" do
        expect(report_class).to receive(:permissions).with(user).and_return []
        get :show_ascena_entry_audit_report
        expect(response).not_to be_success
      end

      it "renders for authorized users" do
        expect(report_class).to receive(:permissions).with(user).and_return([{cust_num: "ASCE", name: "ASCENA TRADE SERVICES LLC"}])
        get :show_ascena_entry_audit_report
        expect(response).to be_success
        expect(assigns(:cust_info)).to eq [["ASCENA TRADE SERVICES LLC", "ASCE"]]
      end
    end

    context "run" do
      let(:args) { {range_field: "release_date", start_release_date: "start release", end_release_date: "end release", start_fiscal_year_month: "start fy/m",
                    end_fiscal_year_month: "end fy/m", cust_number: "ASCE" }}

      it "doesn't run for unauthorized users" do
        expect(report_class).to receive(:permissions).with(user).and_return []
        expect(ReportResult).not_to receive(:run_report!)
        post :run_ascena_entry_audit_report, args
        expect(flash[:errors].first).to eq("You do not have permission to view this report")
      end

      it "runs for authorized users" do
        expect(report_class).to receive(:permissions).with(user).and_return [{cust_num: "ASCE", name: "ASCENA TRADE SERVICES LLC"}]
        expect(ReportResult).to receive(:run_report!).with("Ascena / Ann Inc. / Maurices Entry Audit Report", user, report_class,
                                                           :settings=>args, :friendly_settings=>["Start release date: start release",
                                                                                                 "End release date: end release",
                                                                                                 "Start Fiscal Year/Month: start fy/m",
                                                                                                 "End Fiscal Year/Month: end fy/m",
                                                                                                 "Customer Number: ASCE"])
        post :run_ascena_entry_audit_report, args
        expect(response).to be_redirect
        expect(flash[:notices].first).to eq("Your report has been scheduled. You'll receive a system message when it finishes.")
      end
    end
  end

  describe "Ascena Vendor Scorecard Report" do
    let(:report_class) { OpenChain::CustomHandler::Ascena::AscenaVendorScorecardReport }
    let!(:user) { Factory(:user) }
    let!(:ascena) do
      co = Factory(:importer)
      co.set_system_identifier "Customs Management", "ASCE"
      co
    end
    before { sign_in_as user }

    context "show" do
      it "doesn't render page for unauthorized users" do
        expect(report_class).to receive(:permissions).with(user).and_return []
        get :show_ascena_vendor_scorecard_report
        expect(response).not_to be_success
      end

      it "renders for authorized users" do
        expect(report_class).to receive(:permissions).with(user).and_return([{cust_num: "ASCE", name: "ASCENA TRADE SERVICES LLC"}])
        get :show_ascena_vendor_scorecard_report
        expect(response).to be_success
      end
    end

    context "run" do
      let(:args) { {range_field: "first_release_date", start_release_date: "start release", end_release_date: "end release", start_fiscal_year_month: "start fy/m",
                    end_fiscal_year_month: "end fy/m"}}

      it "doesn't run for unauthorized users" do
        expect(report_class).to receive(:permissions).with(user).and_return []
        expect(ReportResult).not_to receive(:run_report!)
        post :run_ascena_vendor_scorecard_report, args
        expect(flash[:errors].first).to eq("You do not have permission to view this report")
      end

      it "runs for authorized users, including only importers for which they have permission" do
        expect(report_class).to receive(:permissions).with(user).and_return [{cust_num: "ASCE", name: "ASCENA TRADE SERVICES LLC"}, {cust_num: "ANN", name: "ANN INC"}]
        expect(ReportResult).to receive(:run_report!).with("Ascena / Maurices Vendor Scorecard Report", user, report_class, :settings=>args.merge(cust_numbers: ["ASCE", "ANN"]),
                                                                                                                            :friendly_settings=>["Start release date: start release",
                                                                                                                                                 "End release date: end release",
                                                                                                                                                 "Start Fiscal Year/Month: start fy/m",
                                                                                                                                                 "End Fiscal Year/Month: end fy/m",
                                                                                                                                                 "Customer Numbers: ASCE, ANN"])
        post :run_ascena_vendor_scorecard_report, args
        expect(response).to be_redirect
        expect(flash[:notices].first).to eq("Your report has been scheduled. You'll receive a system message when it finishes.")
      end
    end
  end

  describe "Ascena Duty Savings Report" do
    let(:report_class) { OpenChain::CustomHandler::Ascena::AscenaDutySavingsReport }
    let!(:user) { Factory(:user) }
    let!(:ascena) do
      co = Factory(:importer)
      co.set_system_identifier "Customs Management", "ASCE"
      co
    end
    let!(:fm) { Factory(:fiscal_month, company: ascena, year: 2019, month_number: 9) }

    before { sign_in_as user }

    context "show" do
      it "doesn't render page for unauthorized users" do
        expect(report_class).to receive(:permissions).with(user).and_return []
        get :show_ascena_duty_savings_report
        expect(response).not_to be_success
      end

      it "renders for authorized users" do
        expect(report_class).to receive(:permissions).with(user).and_return([{cust_num: "ASCE", name: "ASCENA TRADE SERVICES LLC"}])
        get :show_ascena_duty_savings_report
        expect(response).to be_success
        expect(assigns(:cust_info)).to eq [["ASCENA TRADE SERVICES LLC", "ASCE"]]
        expect(assigns(:fiscal_months)).to eq ["2019-09"]
      end

      it "renders 'Combine companies' option for multiple importers" do
        expect(report_class).to receive(:permissions).with(user).and_return([{cust_num: "ASCE", name: "ASCENA TRADE SERVICES LLC"}, {cust_num: "ATAYLOR", name: "ANN TAYLOR INC"}])
        get :show_ascena_duty_savings_report
        expect(response).to be_success
        expect(assigns(:cust_info)).to eq [["ASCENA TRADE SERVICES LLC", "ASCE"], ["ANN TAYLOR INC", "ATAYLOR"], ["Combine companies", "ASCE,ATAYLOR"]]
      end
    end

    context "run" do
      let(:args) { {'fiscal_month' => "2019-09", 'cust_numbers' => "ASCE,ATAYLOR"} }
      it "doesn't run for unauthorized users" do
        expect(report_class).to receive(:permissions).with(user).and_return []
        expect(ReportResult).not_to receive(:run_report!)
        post :run_ascena_duty_savings_report, args
        expect(flash[:errors].first).to eq("You do not have permission to view this report")
      end

      it "runs for authorized users, including only importers for which they have permission" do
        expect(report_class).to receive(:permissions).with(user).and_return [{cust_num: "ASCE", name: "ASCENA TRADE SERVICES LLC"}]
        expect(ReportResult).to receive(:run_report!).with("Ascena / Ann Inc. / Maurices Duty Savings Report", user, OpenChain::CustomHandler::Ascena::AscenaDutySavingsReport,
                                                           :settings=>{'fiscal_month' => "2019-09", 'cust_numbers' => ["ASCE"]}, :friendly_settings=>["Fiscal Month 2019-09", "Customer Numbers: ASCE"])
        post :run_ascena_duty_savings_report, args
        expect(response).to be_redirect
        expect(flash[:notices].first).to eq("Your report has been scheduled. You'll receive a system message when it finishes.")
      end
    end
  end

  describe "PVH Canada Duty Assist Report" do
    let(:report_class) { OpenChain::CustomHandler::Pvh::PvhDutyAssistReport }
    let!(:user) { Factory(:user) }
    let!(:pvh_canada) { Factory(:company, system_code: "PVHCANADA") }
    let!(:fm) { Factory(:fiscal_month, company: pvh_canada, year: 2020, month_number: 2, start_date: Date.new(2020, 2, 15)) }

    before { sign_in_as user }

    context "show" do
      it "doesn't render page for unauthorized users" do
        expect(report_class).to receive(:permission?).with(user).and_return(false)
        get :show_pvh_canada_duty_assist_report
        expect(response).not_to be_success
      end

      it "renders for authorized users" do
        Factory(:fiscal_month, company: pvh_canada, year: 2020, month_number: 1, start_date: Date.new(2020, 1, 15))

        expect(report_class).to receive(:permission?).with(user).and_return(true)
        get :show_pvh_canada_duty_assist_report
        expect(response).to be_success
        expect(assigns(:fiscal_months)).to eq(["2020-01", "2020-02"])
      end
    end

    context "run" do
      let(:args) { {'fiscal_month' => '2020-01'} }

      it "doesn't run for unauthorized users" do
        expect(report_class).to receive(:permission?).with(user).and_return(false)
        expect(ReportResult).not_to receive(:run_report!)
        post :run_pvh_canada_duty_assist_report, args
        expect(flash[:errors].first).to eq("You do not have permission to view this report")
      end

      it "runs for authorized users" do
        expect(report_class).to receive(:permission?).with(user).and_return(true)
        expect(ReportResult).to receive(:run_report!).with("PVH Canada Duty Assist Report", user, OpenChain::CustomHandler::Pvh::PvhDutyAssistReport,
                                                           settings: {'fiscal_month': "2020-01", 'company': 'PVHCANADA'}, friendly_settings: ["Fiscal Month 2020-01", "Customer Number: PVHCANADA"])
        post :run_pvh_canada_duty_assist_report, args
        expect(response).to be_redirect
        expect(flash[:notices].first).to eq("Your report has been scheduled. You'll receive a system message when it finishes.")
      end
    end
  end

  describe "PVH Duty Assist Report" do
    let(:report_class) { OpenChain::CustomHandler::Pvh::PvhDutyAssistReport }
    let!(:user) { Factory(:user) }
    let!(:pvh) { Factory(:company, system_code: "PVH") }
    let!(:fm) { Factory(:fiscal_month, company: pvh, year: 2020, month_number: 2, start_date: Date.new(2020, 2, 15)) }

    before { sign_in_as user }

    context "show" do
      it "doesn't render page for unauthorized users" do
        expect(report_class).to receive(:permission?).with(user).and_return(false)
        get :show_pvh_duty_assist_report
        expect(response).not_to be_success
      end

      it "renders for authorized users" do
        Factory(:fiscal_month, company: pvh, year: 2020, month_number: 1, start_date: Date.new(2020, 1, 15))

        expect(report_class).to receive(:permission?).with(user).and_return(true)
        get :show_pvh_duty_assist_report
        expect(response).to be_success
        expect(assigns(:fiscal_months)).to eq(["2020-01", "2020-02"])
      end
    end

    context "run" do
      let(:args) { {'fiscal_month' => '2020-01'} }

      it "doesn't run for unauthorized users" do
        expect(report_class).to receive(:permission?).with(user).and_return(false)
        expect(ReportResult).not_to receive(:run_report!)
        post :run_pvh_duty_assist_report, args
        expect(flash[:errors].first).to eq("You do not have permission to view this report")
      end

      it "runs for authorized users" do
        expect(report_class).to receive(:permission?).with(user).and_return(true)
        expect(ReportResult).to receive(:run_report!).with("PVH Duty Assist Report", user, OpenChain::CustomHandler::Pvh::PvhDutyAssistReport,
                                                           settings: {'fiscal_month': "2020-01", 'company': 'PVH'}, friendly_settings: ["Fiscal Month 2020-01", "Customer Number: PVH"])
        post :run_pvh_duty_assist_report, args
        expect(response).to be_redirect
        expect(flash[:notices].first).to eq("Your report has been scheduled. You'll receive a system message when it finishes.")
      end
    end
  end

  describe "Ascena MPF Savings Report" do
    let(:report_class) { OpenChain::CustomHandler::Ascena::AscenaMpfSavingsReport }
    let!(:user) { Factory(:user) }
    let!(:ascena) do
      co = Factory(:importer)
      co.set_system_identifier "Customs Management", "ASCE"
      co
    end
    let!(:fm) { Factory(:fiscal_month, company: ascena, year: 2019, month_number: 9, end_date: Date.new(2019, 10, 31)) }

    before { sign_in_as user }

    context "show" do
      it "doesn't render page for unauthorized users" do
        expect(report_class).to receive(:permissions).with(user).and_return []
        get :show_ascena_mpf_savings_report
        expect(response).not_to be_success
      end

      it "renders for authorized users" do
        expect(report_class).to receive(:permissions).with(user).and_return([{cust_num: "ASCE", name: "ASCENA TRADE SERVICES LLC"}])
        get :show_ascena_mpf_savings_report
        expect(response).to be_success
        expect(assigns(:cust_info)).to eq [["ASCENA TRADE SERVICES LLC", "ASCE"]]
        expect(assigns(:fiscal_months)).to eq ["2019-09"]
      end

      it "renders 'Combine companies' option for multiple importers" do
        expect(report_class).to receive(:permissions).with(user).and_return([{cust_num: "ASCE", name: "ASCENA TRADE SERVICES LLC"}, {cust_num: "ATAYLOR", name: "ANN TAYLOR INC"}])
        get :show_ascena_mpf_savings_report
        expect(response).to be_success
        expect(assigns(:cust_info)).to eq [["ASCENA TRADE SERVICES LLC", "ASCE"], ["ANN TAYLOR INC", "ATAYLOR"], ["Combine companies", "ASCE,ATAYLOR"]]
      end
    end

    context "run" do
      let(:args) { {'fiscal_month' => "2019-09", 'cust_numbers' => "ASCE,ATAYLOR"} }
      it "doesn't run for unauthorized users" do
        expect(report_class).to receive(:permissions).with(user).and_return []
        expect(ReportResult).not_to receive(:run_report!)
        post :run_ascena_mpf_savings_report, args
        expect(flash[:errors].first).to eq("You do not have permission to view this report")
      end

      it "runs for authorized users, including only importers for which they have permission" do
        expect(report_class).to receive(:permissions).with(user).and_return [{cust_num: "ASCE", name: "ASCENA TRADE SERVICES LLC"}]
        expect(ReportResult).to receive(:run_report!).with("Ascena / Ann Inc. / Maurices MPF Savings Report", user, OpenChain::CustomHandler::Ascena::AscenaMpfSavingsReport,
                                                           :settings=>{'fiscal_month' => "2019-09", 'cust_numbers' => ["ASCE"]}, :friendly_settings=>["Fiscal Month 2019-09", "Customer Numbers: ASCE"])
        post :run_ascena_mpf_savings_report, args
        expect(response).to be_redirect
        expect(flash[:notices].first).to eq("Your report has been scheduled. You'll receive a system message when it finishes.")
      end
    end
  end

  describe "Eddie Bauer CA K84 Summary" do
    before :each do
      @ms = stub_master_setup
      allow(@ms).to receive(:custom_feature?).with("WWW VFI Track Reports").and_return true
      @u = Factory(:master_user)
      allow(@u).to receive(:view_entries?).and_return true
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

  describe "Lumber Order Snapshot Discrepancy Report" do
    let(:report_class) { OpenChain::CustomHandler::LumberLiquidators::LumberOrderSnapshotDiscrepancyReport }
    let(:user) { Factory(:user) }
    before { sign_in_as user }

    context "show" do
      it "doesn't render page for unauthorized users" do
        expect(report_class).to receive(:permission?).with(user).and_return false
        get :show_lumber_order_snapshot_discrepancy_report
        expect(response).not_to be_success
        expect(flash[:errors].first).to eq("You do not have permission to view this report.")
      end

      it "renders for authorized users" do
        expect(report_class).to receive(:permission?).with(user).and_return true
        get :show_lumber_order_snapshot_discrepancy_report
        expect(response).to be_success
      end
    end

    context "run" do
      it "doesn't run for unauthorized users" do
        expect(report_class).to receive(:permission?).with(user).and_return false
        expect(ReportResult).not_to receive(:run_report!)
        post :run_lumber_order_snapshot_discrepancy_report, {}
        expect(flash[:errors].first).to eq("You do not have permission to view this report.")
      end

      it "doesn't run when no date arguments and false open orders argument provided" do
        expect(report_class).to receive(:permission?).with(user).and_return true
        expect(ReportResult).not_to receive(:run_report!)
        post :run_lumber_order_snapshot_discrepancy_report, { open_orders_only:false }
        expect(flash[:errors].first).to eq("You must enter a snapshot start and end date, or choose to include open orders only.")
      end

      it "doesn't run when only empty arguments provided" do
        expect(report_class).to receive(:permission?).with(user).and_return true
        expect(ReportResult).not_to receive(:run_report!)
        post :run_lumber_order_snapshot_discrepancy_report, { open_orders_only:"", snapshot_range_start_date:"", snapshot_range_end_date:"" }
        expect(flash[:errors].first).to eq("You must enter a snapshot start and end date, or choose to include open orders only.")
      end

      it "runs for authorized users, all arguments provided" do
        args = { open_orders_only:true, snapshot_range_start_date:"2018-01-01", snapshot_range_end_date:"2018-02-01" }
        expect(report_class).to receive(:permission?).with(user).and_return true
        expect(ReportResult).to receive(:run_report!).with("Order Snapshot Discrepancy Report", user,
            OpenChain::CustomHandler::LumberLiquidators::LumberOrderSnapshotDiscrepancyReport, :settings=>args,
            :friendly_settings=>["Open orders only. Snapshot Date on or after 2018-01-01. Snapshot Date before 2018-02-01."])
        post :run_lumber_order_snapshot_discrepancy_report, args
        expect(response).to be_redirect
        expect(flash[:notices].first).to eq("Your report has been scheduled. You'll receive a system message when it finishes.")
      end

      it "runs for authorized users, missing date arguments" do
        args = { open_orders_only:true }
        expect(report_class).to receive(:permission?).with(user).and_return true
        expect(ReportResult).to receive(:run_report!).with("Order Snapshot Discrepancy Report", user,
           OpenChain::CustomHandler::LumberLiquidators::LumberOrderSnapshotDiscrepancyReport, :settings=>args,
           :friendly_settings=>["Open orders only."])
        post :run_lumber_order_snapshot_discrepancy_report, args
        expect(response).to be_redirect
        expect(flash[:notices].first).to eq("Your report has been scheduled. You'll receive a system message when it finishes.")
      end

      it "runs for authorized users, false open orders argument" do
        args = { open_orders_only:false, snapshot_range_start_date:"2018-01-01", snapshot_range_end_date:"2018-02-01" }
        expect(report_class).to receive(:permission?).with(user).and_return true
        expect(ReportResult).to receive(:run_report!).with("Order Snapshot Discrepancy Report", user,
           OpenChain::CustomHandler::LumberLiquidators::LumberOrderSnapshotDiscrepancyReport, :settings=>args,
           :friendly_settings=>["Snapshot Date on or after 2018-01-01. Snapshot Date before 2018-02-01."])
        post :run_lumber_order_snapshot_discrepancy_report, args
        expect(response).to be_redirect
        expect(flash[:notices].first).to eq("Your report has been scheduled. You'll receive a system message when it finishes.")
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

        us_company_1 = with_customs_management_id(Factory(:importer, name:'US-Z'), '12345')
        us_company_2 = with_customs_management_id(Factory(:importer, name:'US-A'), '23456')
        ca_company_1 = with_fenix_id(Factory(:importer, name:'CA-Z'), '12345')
        ca_company_2 = with_fenix_id(Factory(:importer, name:'CA-A'), '23456')

        expect(report_class).to receive(:permission?).with(user).and_return true
        get :show_customer_year_over_year_report
        expect(response).to be_success

        # Ensure importer instance variables, used for dropdowns, were loaded properly.
        us_importers = subject.instance_variable_get(:@us_importers)
        expect(us_importers.length).to eq 2
        expect(us_importers[0]).to eq(['US-A (23456)', us_company_2.id])
        expect(us_importers[1]).to eq(['US-Z (12345)', us_company_1.id])

        ca_importers = subject.instance_variable_get(:@ca_importers)
        expect(ca_importers.length).to eq 2
        expect(ca_importers[0]).to eq(['CA-A (23456)', ca_company_2.id])
        expect(ca_importers[1]).to eq(['CA-Z (12345)', ca_company_1.id])
      end

      it "renders for authorized users, typical user" do
        us_company_1 = with_customs_management_id(Factory(:importer, name:'US-A'), '23456')

        user.company.customer = true
        user.company.linked_companies << us_company_1
        user.save!

        us_company_2 = with_customs_management_id(Factory(:importer, name:'US-Z'), '12345')
        ca_company = with_fenix_id(Factory(:importer, name:'CA-Z'), '12345')

        expect(report_class).to receive(:permission?).with(user).and_return true
        get :show_customer_year_over_year_report
        expect(response).to be_success

        # Ensure importer instance variables, used for dropdowns, were loaded properly.
        us_importers = subject.instance_variable_get(:@us_importers)
        expect(us_importers.length).to eq 1
        expect(us_importers[0]).to eq(['US-A (23456)', us_company_1.id])

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
        expect(user).to receive(:admin?).and_return false

        expect(report_class).to receive(:permission?).with(user).and_return true
        expect(ReportResult).to receive(:run_report!).with("Entry Year Over Year Report", user, OpenChain::Report::CustomerYearOverYearReport,
                                          :settings=>{range_field:'some_date', importer_ids:[5], year_1:'2015', year_2:'2017',
                                                      ca:false, include_cotton_fee:true, include_taxes:false, include_other_fees:false,
                                                      mode_of_transport:['Sea'], entry_types:['01', '02'], include_isf_fees:true,
                                                      include_port_breakdown:false, group_by_mode_of_transport:true, include_line_graphs:true,
                                                      sum_units_by_mode_of_transport:true }, :friendly_settings=>[])
        post :run_customer_year_over_year_report, {range_field:'some_date', country:'US', importer_id_us:['5'], importer_id_ca:['6'],
                                                   year_1:'2015', year_2: '2017', cotton_fee:'true', taxes:'false', other_fees:nil,
                                                   mode_of_transport:['Sea'], entry_types:"01\r\n\r\n02\r\n", isf_fees:'true',
                                                   port_breakdown:'false', group_by_mode_of_transport:'true', line_graphs:'true',
                                                   sum_units_by_mode_of_transport:'true' }
        expect(response).to be_redirect
        expect(flash[:notices].first).to eq("Your report has been scheduled. You'll receive a system message when it finishes.")
      end

      it "runs for authorized users, CA importer" do
        expect(user).to receive(:admin?).and_return false

        expect(report_class).to receive(:permission?).with(user).and_return true
        expect(ReportResult).to receive(:run_report!).with("Entry Year Over Year Report", user, OpenChain::Report::CustomerYearOverYearReport,
                                         :settings=>{range_field:'some_date', importer_ids:[6, 7], ca:true, year_1:'2015', year_2:'2017',
                                                     include_cotton_fee:false, include_taxes:false, include_other_fees:false,
                                                     mode_of_transport:['Sea'], entry_types:['01', '02'], include_isf_fees:false,
                                                     include_port_breakdown:true, group_by_mode_of_transport:false, include_line_graphs:false,
                                                     sum_units_by_mode_of_transport:false }, :friendly_settings=>[])
        post :run_customer_year_over_year_report, {range_field:'some_date', country:'CA', importer_id_us:['5'], importer_id_ca:['6', '7'],
                                          year_1:'2015', year_2: '2017', cotton_fee:nil, taxes:nil, other_fees:nil,
                                          mode_of_transport:['Sea'], entry_types:"01\r\n02", isf_fees:nil,
                                          port_breakdown:'true', group_by_mode_of_transport:'false', line_graphs:'false',
                                          sum_units_by_mode_of_transport:'false'}
        expect(response).to be_redirect
        expect(flash[:notices].first).to eq("Your report has been scheduled. You'll receive a system message when it finishes.")
      end

      it "fails if importer is not selected (US)" do
        expect(user).to receive(:admin?).and_return false

        expect(report_class).to receive(:permission?).with(user).and_return true
        expect(ReportResult).not_to receive(:run_report!)
        post :run_customer_year_over_year_report, {range_field:'some_date', country:'US', importer_id_us:[], importer_id_ca:['6'],
                                          year_1:'2015', year_2: '2017'}
        expect(response).to be_redirect
        expect(flash[:errors].first).to eq("At least one importer must be selected.")
        expect(flash[:notices]).to be_nil
      end

      it "fails if importer is not selected (CA)" do
        expect(user).to receive(:admin?).and_return false

        expect(report_class).to receive(:permission?).with(user).and_return true
        expect(ReportResult).not_to receive(:run_report!)
        post :run_customer_year_over_year_report, {range_field:'some_date', country:'CA', importer_id_us:['5'], importer_id_ca:nil,
                                          year_1:'2015', year_2: '2017'}
        expect(response).to be_redirect
        expect(flash[:errors].first).to eq("At least one importer must be selected.")
        expect(flash[:notices]).to be_nil
      end

      it "runs for admin users" do
        expect(user).to receive(:admin?).and_return true

        importer_1 = with_customs_management_id(Factory(:company), 'SYS01')
        importer_2 = with_fenix_id(Factory(:company), 'SYS02')
        # No match should be made for this even though there is a blank line in the input.
        importer_3 = Factory(:company, alliance_customer_number:'')

        expect(report_class).to receive(:permission?).with(user).and_return true
        expect(ReportResult).to receive(:run_report!).with("Entry Year Over Year Report", user, OpenChain::Report::CustomerYearOverYearReport,
                                                           :settings=>{range_field:'some_date', importer_ids:[importer_1.id, importer_2.id], ca: false,
                                                                       year_1:'2015', year_2:'2017', include_cotton_fee:false, include_taxes:true, include_other_fees:true,
                                                                       mode_of_transport:['Sea'], entry_types:['01', '02'], include_isf_fees:false,
                                                                       include_port_breakdown:true, group_by_mode_of_transport:false, include_line_graphs:false,
                                                                       sum_units_by_mode_of_transport:false }, :friendly_settings=>[])
        post :run_customer_year_over_year_report, {range_field:'some_date', importer_customer_numbers:" SYS01  \r\n\r\ninvalid_code\r\nSYS02\r\n",
                                                   year_1:'2015', year_2: '2017', cotton_fee:'false', taxes:'true', other_fees:'true',
                                                   mode_of_transport:['Sea'], entry_types:"01\r\n02", isf_fees:'false',
                                                   port_breakdown:'true', group_by_mode_of_transport:'false', sum_units_by_mode_of_transport:'false'}
        expect(response).to be_redirect
        expect(flash[:errors]).to be_nil
        expect(flash[:notices].first).to eq("Your report has been scheduled. You'll receive a system message when it finishes.")
      end

      it "fails for admin users when no importer customer codes are provided" do
        expect(user).to receive(:admin?).and_return true

        expect(report_class).to receive(:permission?).with(user).and_return true
        expect(ReportResult).not_to receive(:run_report!)
        post :run_customer_year_over_year_report, {range_field:'some_date', importer_customer_numbers:'   ',
                                                   year_1:'2015', year_2: '2017', cotton_fee:'false', taxes:'true', other_fees:'true',
                                                   mode_of_transport:['Sea'], entry_types:['01', '02'], isf_fees:'false',
                                                   port_breakdown:'true', group_by_mode_of_transport:'false'}
        expect(response).to be_redirect
        expect(flash[:errors].first).to eq("At least one importer must be selected.")
        expect(flash[:notices]).to be_nil
      end
    end
  end

  describe "Company Year Over Year Report" do
    let(:report_class) { OpenChain::Report::CompanyYearOverYearReport }
    let(:user) { Factory(:user) }
    before { sign_in_as user }

    context "show" do
      it "doesn't render page for unauthorized users" do
        expect(report_class).to receive(:permission?).with(user).and_return false
        get :show_company_year_over_year_report
        expect(response).not_to be_success
      end

      it "renders for authorized users" do
        expect(report_class).to receive(:permission?).with(user).and_return true
        get :show_company_year_over_year_report
        expect(response).to be_success
      end
    end

    context "run" do
      it "doesn't run for unauthorized users" do
        expect(report_class).to receive(:permission?).with(user).and_return false
        expect(ReportResult).not_to receive(:run_report!)
        post :run_company_year_over_year_report, {}
        expect(response).to be_redirect
        expect(flash[:errors].first).to eq("You do not have permission to view this report")
        expect(flash[:notices]).to be_nil
      end

      it "runs for authorized users" do
        expect(report_class).to receive(:permission?).with(user).and_return true
        expect(ReportResult).to receive(:run_report!).with("Company Year Over Year Report", user, OpenChain::Report::CompanyYearOverYearReport,
                                         :settings=>{year_1:'2015', year_2:'2017'}, :friendly_settings=>[])
        post :run_company_year_over_year_report, {year_1:'2015', year_2: '2017'}
        expect(response).to be_redirect
        expect(flash[:notices].first).to eq("Your report has been scheduled. You'll receive a system message when it finishes.")
      end
    end
  end

  describe "Puma Division Quarter Breakdown" do
    let(:report_class) { OpenChain::Report::PumaDivisionQuarterBreakdown }
    let(:user) { Factory(:user) }
    before { sign_in_as user }

    context "show" do
      it "doesn't render page for unauthorized users" do
        expect(report_class).to receive(:permission?).with(user).and_return false
        get :show_puma_division_quarter_breakdown
        expect(response).not_to be_success
      end

      it "renders for authorized users" do
        expect(report_class).to receive(:permission?).with(user).and_return true
        get :show_puma_division_quarter_breakdown
        expect(response).to be_success
      end
    end

    context "run" do
      it "doesn't run for unauthorized users" do
        expect(report_class).to receive(:permission?).with(user).and_return false
        expect(ReportResult).not_to receive(:run_report!)
        post :run_puma_division_quarter_breakdown, {}
        expect(response).to be_redirect
        expect(flash[:errors].first).to eq("You do not have permission to view this report")
        expect(flash[:notices]).to be_nil
      end

      it "runs for authorized users" do
        expect(report_class).to receive(:permission?).with(user).and_return true
        expect(ReportResult).to receive(:run_report!).with("Puma Division Quarter Breakdown", user, OpenChain::Report::PumaDivisionQuarterBreakdown,
                                                           :settings=>{year:'2015'}, :friendly_settings=>[])
        post :run_puma_division_quarter_breakdown, {year:'2015'}
        expect(response).to be_redirect
        expect(flash[:notices].first).to eq("Your report has been scheduled. You'll receive a system message when it finishes.")
      end
    end
  end

  describe "US Billing Report" do
    let(:report_class) { OpenChain::Report::UsBillingSummary }
    let(:user) { Factory(:user) }
    before { sign_in_as user }

    context "show" do
      it "doesn't render page for unauthorized user" do
        expect(report_class).to receive(:permission?).with(user).and_return false
        get :show_us_billing_summary
        expect(response).not_to be_success
      end

      it "renders for authorized user" do
        co_1 = with_customs_management_id(Factory(:importer, name: "ACME US"), "ACME")
        co_2 = with_fenix_id(Factory(:importer, name: "ACME CA"), "ACME CA")

        expect(report_class).to receive(:permission?).with(user).and_return true
        get :show_us_billing_summary
        expect(assigns(:us_importers).to_a).to eq [co_1]
        expect(response).to be_success
      end
    end

    context "run" do
      it "doesn't run for unauthorized user" do
        expect(report_class).to receive(:permission?).with(user).and_return false
        expect(ReportResult).not_to receive(:run_report!)
        post :run_us_billing_summary, {}
        expect(response).to be_redirect
        expect(flash[:errors].first).to eq "You do not have permission to view this report"
        expect(flash[:notices]).to be_nil
      end

      it "runs for authorized user" do
        expect(report_class).to receive(:permission?).with(user).and_return true
        expect(ReportResult).to receive(:run_report!).with("US Billing Summary", user, OpenChain::Report::UsBillingSummary,
                                         :settings=>{start_date:'2019-03-03', end_date:'2019-03-10', customer_number: 'ACME'},
                                         :friendly_settings=>["Customer Number: ACME", "Start Date: 2019-03-03", "End Date: 2019-03-10"])
        post :run_us_billing_summary, {start_date:'2019-03-03', end_date: '2019-03-10', customer_number: 'ACME'}
        expect(response).to be_redirect
        expect(flash[:notices].first).to eq "Your report has been scheduled. You'll receive a system message when it finishes."
      end

      it "errors if dates cross" do
        expect(report_class).to receive(:permission?).with(user).and_return true
        expect(ReportResult).to_not receive(:run_report!)
        post :run_us_billing_summary, {start_date:'2019-03-10', end_date: '2019-03-03', customer_number: 'ACME'}
        expect(response).to be_redirect
        expect(flash[:errors].first).to eq "The start date must precede the end date."
      end
    end
  end

  describe "H&M Canada Drawback Report" do
    let(:report_class) { OpenChain::Report::HmCanadaDrawbackReport }
    let(:user) { Factory(:user) }
    before { sign_in_as user }

    context "show" do
      it "doesn't render page for unauthorized users" do
        expect(report_class).to receive(:permission?).with(user).and_return false
        get :show_hm_canada_drawback_report
        expect(response).not_to be_success
      end

      it "renders for authorized users" do
        expect(report_class).to receive(:permission?).with(user).and_return true
        get :show_hm_canada_drawback_report
        expect(response).to be_success
      end
    end

    context "run" do
      it "doesn't run for unauthorized users" do
        expect(report_class).to receive(:permission?).with(user).and_return false
        expect(ReportResult).not_to receive(:run_report!)
        post :run_hm_canada_drawback_report, {}
        expect(response).to be_redirect
        expect(flash[:errors].first).to eq("You do not have permission to view this report")
        expect(flash[:notices]).to be_nil
      end

      it "runs for authorized users" do
        expect(report_class).to receive(:permission?).with(user).and_return true
        expect(ReportResult).to receive(:run_report!).with("H&M Canada Drawback Report", user,
                                                           OpenChain::Report::HmCanadaDrawbackReport,
                                                           :settings=>{start_date:'2018-08-08', end_date:'2019-09-09'}, :friendly_settings=>[])
        post :run_hm_canada_drawback_report, {start_date:'2018-08-08', end_date:'2019-09-09'}
        expect(response).to be_redirect
        expect(flash[:notices].first).to eq("Your report has been scheduled. You'll receive a system message when it finishes.")
      end
    end

    describe "PVH Duty Discount Report" do
      let(:report_class) { OpenChain::Report::PvhDutyDiscountReport }
      let(:user) { Factory(:user) }
      before { sign_in_as user }

      context "show" do
        it "doesn't render page for unauthorized users" do
          expect(report_class).to receive(:permission?).with(user).and_return false
          get :show_pvh_duty_discount_report
          expect(response).not_to be_success
        end

        it "renders for authorized users" do
          pvh = Factory(:company, name:'PVH', system_code:'PVH')
          pvh_ca = Factory(:company, name:'PVH', system_code:'PVHCANADA')

          FiscalMonth.create!(company_id:pvh.id, year:2019, month_number:3, start_date:Date.new(2019, 4, 1))
          FiscalMonth.create!(company_id:pvh.id, year:2019, month_number:2, start_date:Date.new(2019, 2, 20))
          FiscalMonth.create!(company_id:pvh_ca.id, year:2019, month_number:2, start_date:Date.new(2019, 3, 1))
          FiscalMonth.create!(company_id:pvh_ca.id, year:2019, month_number:1, start_date:Date.new(2019, 1, 20))

          expect(report_class).to receive(:permission?).with(user).and_return true
          get :show_pvh_duty_discount_report
          expect(response).to be_success

          # Ensure fiscal month instance variables, used for dropdowns, were loaded properly.
          # They should be sorted by start date.
          fiscal_months_us = subject.instance_variable_get(:@fiscal_months_us)
          expect(fiscal_months_us.length).to eq 2
          expect(fiscal_months_us[0]).to eq '2019-02'
          expect(fiscal_months_us[1]).to eq '2019-03'

          fiscal_months_ca = subject.instance_variable_get(:@fiscal_months_canada)
          expect(fiscal_months_ca.length).to eq 2
          expect(fiscal_months_ca[0]).to eq '2019-01'
          expect(fiscal_months_ca[1]).to eq '2019-02'
        end
      end

      context "run" do
        it "doesn't run for unauthorized users" do
          expect(report_class).to receive(:permission?).with(user).and_return false
          expect(ReportResult).not_to receive(:run_report!)
          post :run_pvh_duty_discount_report, {}
          expect(response).to be_redirect
          expect(flash[:errors].first).to eq("You do not have permission to view this report")
          expect(flash[:notices]).to be_nil
        end

        it "runs for authorized users (US)" do
          expect(report_class).to receive(:permission?).with(user).and_return true
          expect(ReportResult).to receive(:run_report!).with("PVH Duty Discount Report", user,
                                                             OpenChain::Report::PvhDutyDiscountReport,
                                                             :settings=>{fiscal_month:'2019-04'}, :friendly_settings=>[])
          post :run_pvh_duty_discount_report, {importer:'PVH', fiscal_month_us:'2019-04'}
          expect(response).to be_redirect
          expect(flash[:notices].first).to eq("Your report has been scheduled. You'll receive a system message when it finishes.")
        end

        it "runs for authorized users (CA)" do
          expect(report_class).to receive(:permission?).with(user).and_return true
          expect(ReportResult).to receive(:run_report!).with("PVH Canada Duty Discount Report", user,
                                                             OpenChain::Report::PvhCanadaDutyDiscountReport,
                                                             :settings=>{fiscal_month:'2019-04'}, :friendly_settings=>[])
          post :run_pvh_duty_discount_report, {importer:'PVH Canada', fiscal_month_canada:'2019-04'}
          expect(response).to be_redirect
          expect(flash[:notices].first).to eq("Your report has been scheduled. You'll receive a system message when it finishes.")
        end

        it "errors when importer is not selected" do
          expect(report_class).to receive(:permission?).with(user).and_return true

          expect(ReportResult).not_to receive(:run_report!)
          post :run_pvh_duty_discount_report, {fiscal_month:'2019-04', mode_of_transport:'Sea'}
          expect(response).to be_redirect
          expect(flash[:errors].first).to eq("An importer must be selected.")
          expect(flash[:notices]).to be_nil
        end
      end
    end
  end

  describe "PVH First Cost Savings Report" do
    let(:report_class) { OpenChain::Report::PvhFirstCostSavingsReport }
    let(:user) { Factory(:user) }
    before { sign_in_as user }

    context "show" do
      it "doesn't render page for unauthorized users" do
        expect(report_class).to receive(:permission?).with(user).and_return false
        get :show_pvh_first_cost_savings_report
        expect(response).not_to be_success
      end

      it "renders for authorized users" do
        pvh = Factory(:company, name:'PVH', system_code:'PVH')
        another_importer = Factory(:company, name:'Another Importer', system_code:'imp')

        FiscalMonth.create!(company_id:pvh.id, year:2019, month_number:3, start_date:Date.new(2019, 4, 1))
        FiscalMonth.create!(company_id:pvh.id, year:2019, month_number:2, start_date:Date.new(2019, 2, 20))
        # This one belongs to a different importer and should not be included.
        FiscalMonth.create!(company_id:another_importer.id, year:2019, month_number:4, start_date:Date.new(2019, 7, 1))

        expect(report_class).to receive(:permission?).with(user).and_return true
        get :show_pvh_first_cost_savings_report
        expect(response).to be_success

        # Ensure fiscal month instance variables, used for dropdowns, were loaded properly.
        # They should be sorted by start date.
        fiscal_months = subject.instance_variable_get(:@fiscal_months)
        expect(fiscal_months.length).to eq 2
        expect(fiscal_months[0]).to eq '2019-02'
        expect(fiscal_months[1]).to eq '2019-03'
      end
    end

    context "run" do
      it "doesn't run for unauthorized users" do
        expect(report_class).to receive(:permission?).with(user).and_return false
        expect(ReportResult).not_to receive(:run_report!)
        post :run_pvh_first_cost_savings_report, {}
        expect(response).to be_redirect
        expect(flash[:errors].first).to eq("You do not have permission to view this report")
        expect(flash[:notices]).to be_nil
      end

      it "runs for authorized users" do
        expect(report_class).to receive(:permission?).with(user).and_return true
        expect(ReportResult).to receive(:run_report!).with("PVH First Cost Savings Report", user,
                                                           OpenChain::Report::PvhFirstCostSavingsReport,
                                                           :settings=>{fiscal_month:'2019-04'}, :friendly_settings=>[])
        post :run_pvh_first_cost_savings_report, {fiscal_month:'2019-04'}
        expect(response).to be_redirect
        expect(flash[:notices].first).to eq("Your report has been scheduled. You'll receive a system message when it finishes.")
      end
    end
  end

end
