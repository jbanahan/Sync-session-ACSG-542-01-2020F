require 'spec_helper'

describe TariffSetsController do

  describe "index" do

    before(:each) do
      @u = Factory(:user)
      @c1 = Factory(:country)
      c2 = Factory(:country)
      [@c1,c2].each do |c|
        #a : z stuff is to make sure they're not in alphabetical order in the DB
        5.times {|i| c.tariff_sets.create!(:label=>"#{i.modulo(2)==0 ? "a" : "z"}#{i}")}
      end
      activate_authlogic
      UserSession.create @u
    end

    it "should return all sets with no parameters" do
      get :index
      response.should be_success
      t = ActiveSupport::JSON.decode response.body
      t.should have(10).things
    end
    
    it "should return for a single country" do
      get :index, :country_id => @c1.id
      response.should be_success
      t = ActiveSupport::JSON.decode response.body
      t.should have(5).things
      t.each {|s| s['tariff_set']['country_id'].should == @c1.id}
    end

    it "should sort tariff sets alphabetically descending" do
      get :index
      t = ActiveSupport::JSON.decode response.body
      tariff_sets = t.collect {|s| TariffSet.find s['tariff_set']['id']}
      tariff_sets.should be_alphabetical_descending_by :label
    end
  end

end
