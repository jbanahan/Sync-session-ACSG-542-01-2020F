require 'spec_helper'

describe TariffSetsController do

  describe "index" do

    before(:each) do
      Country.destroy_all
      TariffSet.destroy_all
      @user = Factory(:user)

      sign_in_as @user
      @c1 = Factory(:country)
      c2 = Factory(:country)
      [@c1,c2].each do |c|
        #a : z stuff is to make sure they're not in alphabetical order in the DB
        5.times {|i| c.tariff_sets.create!(:label=>"#{i.modulo(2)==0 ? "a" : "z"}#{i}")}
      end
    end

    it "should return all sets with no parameters" do
      get :index, :format=>:json
      response.should be_success
      t = ActiveSupport::JSON.decode response.body
      t.should have(10).things
    end
    
    it "should return for a single country" do
      get :index, :format=>:json, :country_id => @c1.id
      response.should be_success
      t = ActiveSupport::JSON.decode response.body
      t.should have(5).things
      t.each {|s| s['tariff_set']['country_id'].should == @c1.id}
    end

    it "should sort tariff sets alphabetically descending by country" do
      get :index, :format=>:json, :country_id => @c1.id
      t = ActiveSupport::JSON.decode response.body
      tariff_sets = t.collect {|s| TariffSet.find s['tariff_set']['id']}
      tariff_sets.should be_alphabetical_descending_by :label
    end
  end

  describe "load" do
    before :each do
      Country.destroy_all
      @country = Factory(:country)
    end
    context 'security' do
      it 'should not allow non-sys admins' do
        @user = Factory(:user)

        sign_in_as @user
        TariffLoader.should_not_receive(:delay)
        post :load, :country_id=>@country.id, :path=>'abc', :label=>'abcd'
        response.should be_redirect
        flash[:errors].should include "Only system administrators can load tariff sets."
      end
    end
    context 'behavior' do
      before :each do
        @user = Factory(:user,:sys_admin=>true, :time_zone=>'Hawaii')

        sign_in_as @user
      end
      it 'should delay load from s3 and without activating' do
        Country.should_receive(:find).with(@country.id.to_s).and_return(@country)
        TariffLoader.should_receive(:delay).and_return(TariffLoader)
        TariffLoader.should_receive(:process_s3).with('abc',@country,'lbl',false,instance_of(User))
        post :load, :country_id=>@country.id, :path=>'abc', :label=>'lbl'
      end
      it 'should delay load from s3 and without activating and run at date specified from params' do
        Country.should_receive(:find).with(@country.id.to_s).and_return(@country)
        TariffLoader.should_receive(:delay).with(:run_at => ActiveSupport::TimeZone[@user.time_zone].parse("2012-01-01 01:01")).and_return(TariffLoader)
        TariffLoader.should_receive(:process_s3).with('abc',@country,'lbl',false,instance_of(User))
        post :load, :country_id=>@country.id, :path=>'abc', :label=>'lbl', :date => {:year => "2012", :month=>1, :day => 1, :hour=>1, :minute => 1}
      end
      it 'should delay load from s3 and activate' do
        Country.should_receive(:find).with(@country.id.to_s).and_return(@country)
        TariffLoader.should_receive(:delay).and_return(TariffLoader)
        TariffLoader.should_receive(:process_s3).with('abc',@country,'lbl',true,instance_of(User))
        post :load, :country_id=>@country.id, :path=>'abc', :label=>'lbl', :activate=>'yes'
      end
    end
  end
  describe "activate" do
    before :each do
      Country.destroy_all
      @country = Factory(:country)
      @tariff_set = @country.tariff_sets.create!(:label=>'mylabel')
    end
    context 'security' do
      it 'should not allow non admins' do
        @user = Factory(:user)

        sign_in_as @user
        get :activate, :id=>@tariff_set.id
        response.should be_redirect
        flash[:errors].should include "You must be an administrator to activate tariffs."
      end
    end
    it 'should call delayed activate and write flash message' do
      @user = Factory(:user,:admin=>true)

      sign_in_as @user
      TariffSet.should_receive(:find).with(@tariff_set.id.to_s).and_return(@tariff_set)
      @tariff_set.should_receive(:delay).and_return(@tariff_set)
      @tariff_set.should_receive(:activate).with(instance_of(User)).and_return(nil)
      get :activate, :id=>@tariff_set.id
      response.should be_redirect
      flash[:notices].should include "Tariff Set #{@tariff_set.label} is being activated in the background.  You'll receive a system message when it is complete."
    end
  end
end
