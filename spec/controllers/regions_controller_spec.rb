require 'spec_helper'

describe RegionsController do
  
  before :each do
    activate_authlogic
  end
  describe :security do
    before :each do
      @u = Factory(:user)
      UserSession.create! @u
    end
    after :each do
      response.should redirect_to request.referrer
    end
    it "should restrict index" do
      get :index
    end
    it "should restrict create" do
      post :create, :name=>"EMEA", :format=>:json
      Region.find_by_name("EMEA").should be_nil
    end
    it "should restrict destroy" do
      r = Factory(:region,:name=>"EMEA")
      delete :destroy, :id=>r.id
      Region.find_by_name("EMEA").should_not be_nil
    end
    before :each do
      @r = Factory(:region)
      @c = Factory(:country)
    end
    it "should restrict add country" do
      get :add_country, :id=>@r.id, :country_id=>@c.id
      @r.reload
      @r.countries.to_a.should be_empty
    end
    it "should restrict remove country" do
      @r.countries << @c
      get :remove_country, :id=>@r.id, :country_id=>@c.id
      @r.reload
      @r.countries.to_a.should == [@c]
    end
  end
  context "security passed" do
    before :each do
      @u = Factory(:admin_user)
      UserSession.create! @u
      @r = Factory(:region)
    end
    describe :index do
      it "should show all regions" do
        r2 = Factory(:region)
        get :index
        response.should be_success
        assigns(:regions).to_a.should == [@r,r2]
      end
    end
    describe :create do
      it "should make new region" do
        post :create, 'region'=>{'name'=>"EMEA"}, :format=>:json
        response.should redirect_to regions_path
      end
    end
    describe :destroy do
      it "should remove region" do
        id = @r.id
        delete :destroy, :id=>id
        response.should redirect_to regions_path
        Region.find_by_id(id).should be_nil
      end
    end
    context "country management" do
      before :each do
        @c = Factory(:country)
      end
      describe :add_country do
        it "should add country to region" do
          get :add_country, :id=>@r.id, :country_id=>@c.id
          response.should redirect_to regions_path
          @r.reload
          @r.countries.to_a.should == [@c]
        end
      end
      describe :remove_country do
        it "should remove country from region" do
          @r.countries << @c
          get :remove_country, :id=>@r.id, :country_id=>@c.id
          response.should redirect_to regions_path
          @r.reload
          @r.countries.to_a.should == []
        end
      end
    end
  end
end
