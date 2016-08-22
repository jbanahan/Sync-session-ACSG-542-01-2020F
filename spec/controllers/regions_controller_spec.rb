require 'spec_helper'

describe RegionsController do
  
  before :each do

  end
  describe "security" do
    before :each do
      @u = Factory(:user)
      sign_in_as @u
    end
    after :each do
      expect(response).to redirect_to request.referrer
    end
    it "should restrict index" do
      get :index
    end
    it "should restrict create" do
      post :create, :name=>"EMEA", :format=>:json
      expect(Region.find_by_name("EMEA")).to be_nil
    end
    it "should restrict destroy" do
      r = Factory(:region,:name=>"EMEA")
      delete :destroy, :id=>r.id
      expect(Region.find_by_name("EMEA")).not_to be_nil
    end
    before :each do
      @r = Factory(:region)
      @c = Factory(:country)
    end
    it "should restrict add country" do
      get :add_country, :id=>@r.id, :country_id=>@c.id
      @r.reload
      expect(@r.countries.to_a).to be_empty
    end
    it "should restrict remove country" do
      @r.countries << @c
      get :remove_country, :id=>@r.id, :country_id=>@c.id
      @r.reload
      expect(@r.countries.to_a).to eq([@c])
    end
  end
  context "security passed" do
    before :each do
      @u = Factory(:admin_user)
      sign_in_as @u
      @r = Factory(:region)
    end
    describe "index" do
      it "should show all regions" do
        r2 = Factory(:region)
        get :index
        expect(response).to be_success
        expect(assigns(:regions).to_a).to eq([@r,r2])
      end
    end
    describe "create" do
      it "should make new region" do
        post :create, 'region'=>{'name'=>"EMEA"}, :format=>:json
        expect(response).to redirect_to regions_path
      end
    end
    describe "destroy" do
      it "should remove region" do
        id = @r.id
        delete :destroy, :id=>id
        expect(response).to redirect_to regions_path
        expect(Region.find_by_id(id)).to be_nil
      end
    end
    context "country management" do
      before :each do
        @c = Factory(:country)
      end
      describe "add_country" do
        it "should add country to region" do
          get :add_country, :id=>@r.id, :country_id=>@c.id
          expect(response).to redirect_to regions_path
          @r.reload
          expect(@r.countries.to_a).to eq([@c])
        end
      end
      describe "remove_country" do
        it "should remove country from region" do
          @r.countries << @c
          get :remove_country, :id=>@r.id, :country_id=>@c.id
          expect(response).to redirect_to regions_path
          @r.reload
          expect(@r.countries.to_a).to eq([])
        end
      end
    end
  end
end
