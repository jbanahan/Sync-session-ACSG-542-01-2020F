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
  describe :push_alliance_products do
    before :each do
      MasterSetup.get.update_attributes(:custom_features=>"alliance")
      @u.admin = true
      @u.save!
      @c.update_attributes(:alliance_customer_number=>"ACNUM")
    end
    it "should initiate delayed_job" do
      post :push_alliance_products, :id=>@c.id
      response.should redirect_to @c
      flash[:notices].should have(1).message
      flash[:errors].should be_blank
      Delayed::Job.all.should have(1).job
    end
    it "should push products" do
      dj_state = Delayed::Worker.delay_jobs
      begin
        Delayed::Worker.delay_jobs = false
        OpenChain::CustomHandler::GenericAllianceProductGenerator.should_receive(:sync).with(instance_of(Company))
        post :push_alliance_products, :id=>@c.id
        response.should redirect_to @c
        flash[:notices].should have(1).message
        flash[:errors].should be_blank
        @c.reload
        @c.last_alliance_product_push_at.should > 1.minute.ago
      ensure
        Delayed::Worker.delay_jobs = dj_state
      end
    end
    it "should reject if alliance custom feature isn't enabled" do
      MasterSetup.get.update_attributes(:custom_features=>"")
      post :push_alliance_products, :id=>@c.id
      flash[:errors].first.should == "Cannot push file because \"alliance\" custom feature is not enabled."
      Delayed::Job.all.should be_empty
    end
    it "should reject if company doesn't have alliance customer number" do
      @c.update_attributes(:alliance_customer_number=>nil)
      post :push_alliance_products, :id=>@c.id
      flash[:errors].first.should == "Cannot push file because company doesn't have an alliance customer number." 
      Delayed::Job.all.should be_empty
    end
    it "should reject if user isn't admin" do
      @u.admin = false
      @u.save!
      post :push_alliance_products, :id=>@c.id
      response.should be_redirect 
      flash[:errors].should have(1).message
      Delayed::Job.all.should be_empty
    end
    it "should reject if job was initiated less than 10 minutes ago" do
      @c.update_attributes :last_alliance_product_push_at=>1.minute.ago
      post :push_alliance_products, :id=>@c.id
      flash[:errors].first.should == "Cannot push file because last push was less than 10 minutes ago." 
      Delayed::Job.all.should be_empty
    end
  end
end
