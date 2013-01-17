require 'spec_helper'

describe CompaniesController do
  before :each do
    activate_authlogic
    @u = Factory(:user,:admin=>true,:company=>Factory(:company,:master=>true))
    UserSession.create! @u
    @c = Factory(:company)
  end
  describe "attachment_archive_enabled" do
    before :each do
      @sd = Date.new(2010,4,18)
      @c.create_attachment_archive_setup :start_date=>@sd
    end
    it "should return json for master user" do
      get :attachment_archive_enabled, :format=>:json
      response.should be_success
      ary = JSON.parse response.body
      ary.should have(1).company
      ary.first['company']['name'].should == @c.name
      ary.first['company']['id'].should == @c.id
      Date.parse(ary.first['company']['attachment_archive_setup']['start_date']).should == @sd
      ary.first['company']['attachment_archive_setup']['entry_attachments_available_count'].should == 0
    end
    it "should fail for non-master user" do
      @u.update_attributes(:company_id=>@c.id)
      get :attachment_archive_enabled, :format=>:json
      response.should redirect_to request.referrer
      flash[:errors].should have(1).entry
    end
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
