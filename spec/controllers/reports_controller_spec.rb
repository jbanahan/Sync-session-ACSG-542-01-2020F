require 'spec_helper'

describe ReportsController do

  before(:each) do
    @u = Factory(:user)
    activate_authlogic
    UserSession.create @u
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
        response.should redirect_to('/reports')
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
        response.should redirect_to('/reports')
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
        UserSession.create @admin
        get :show_poa_expirations
        response.should be_success
      end
    end

    context "run as admin" do
      it "should run report for valid date and admin user" do
        UserSession.create @admin
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

end
