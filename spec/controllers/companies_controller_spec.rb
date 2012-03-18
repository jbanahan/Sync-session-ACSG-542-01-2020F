require 'spec_helper'

describe CompaniesController do
  before :each do
    activate_authlogic
    @u = Factory(:user,:admin=>true,:company=>Factory(:company,:master=>true))
    UserSession.create! @u
    @c = Factory(:company)
  end
  describe 'show_children' do
    it "should reject if user isn't admin" do
      @u.admin = false
      @u.save!
      get :show_children, :id=> @c.id
      response.should redirect_to root_path
      flash[:errors].should have(1).message
    end
    it "should reject if user isn't in master company" do
      @u.company.update_attributes(:master=>false)
      get :show_children, :id=> @c.id
      response.should redirect_to root_path
      flash[:errors].should have(1).message
    end
    it "should split companies into linked and unlinked variables" do
      get :show_children, :id => @c.id
      response.should be_success
      assigns(:company).should == @c
    end
  end
  describe 'update_children' do
    it "should reject if user isn't admin" do
      @u.admin = false
      @u.save!
      post :update_children, { :id=>@c.id, :selected=>{"1"=>"50","2"=>"100"} }
      response.should redirect_to root_path
      flash[:errors].should have(1).message
    end
    it "should reject if user isn't in master company" do
      @u.company.update_attributes(:master=>false)
      post :update_children, { :id=>@c.id, :selected=>{"1"=>"50","2"=>"100"} }
      response.should redirect_to root_path
      flash[:errors].should have(1).message
    end
    it "should replace children" do
      c1 = Factory(:company)
      c2 = Factory(:company)
      c3 = Factory(:company)
      @c.linked_companies << c1
      post :update_children, { :id=>@c.id, :selected=>{"1"=>c2.id.to_s,"2"=>c3.id.to_s} }
      response.should redirect_to show_children_company_path @c
      Company.find(@c.id).linked_companies.to_a.should == [c2,c3]
    end
  end
end
