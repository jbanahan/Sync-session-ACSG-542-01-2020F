require 'spec_helper'

describe ReportsController do

  before(:each) do
    @u = Factory(:user)
    activate_authlogic
    UserSession.create @u
  end

  describe 'tariff comparison report' do
    before(:all) do
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
      before(:all) do
        Delayed::Worker.delay_jobs = false
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

end
