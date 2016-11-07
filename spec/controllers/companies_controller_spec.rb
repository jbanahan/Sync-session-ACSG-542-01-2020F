require 'spec_helper'

describe CompaniesController do
  before :each do
    @u = Factory(:user,:admin=>true,:company=>Factory(:company,:master=>true))
    sign_in_as @u
    @c = Factory(:company)
  end

  describe "create" do
    it "should trigger snapshot" do
      allow(OpenChain::WorkflowProcessor).to receive(:async_process)
      expect{post :create, {'company'=>{'cmp_name'=>'mycompany'}}}.to change(Company,:count).by(1)
      c = Company.last
      expect(c.entity_snapshots.count).to eq 1
    end
  end
  describe "update" do
    it "should trigger snapshot" do
      allow(OpenChain::WorkflowProcessor).to receive(:async_process)
      put :update, {'id'=>@c.id, 'company'=>{'cmp_name'=>'mycompany'}}
      expect(@c.entity_snapshots.count).to eq 1
    end
  end
  describe "attachment_archive_enabled" do
    before :each do
      @sd = Date.new(2010,4,18)
      @c.create_attachment_archive_setup :start_date=>@sd
    end
    it "should return json for master user" do
      get :attachment_archive_enabled, :format=>:json
      expect(response).to be_success
      ary = JSON.parse response.body
      expect(ary.size).to eq(1)
      expect(ary.first['company']['name']).to eq(@c.name)
      expect(ary.first['company']['id']).to eq(@c.id)
      expect(Date.parse(ary.first['company']['attachment_archive_setup']['start_date'])).to eq(@sd)
      expect(ary.first['company']['attachment_archive_setup']['entry_attachments_available_count']).to eq(0)
    end
    it "should fail for non-master user" do
      @u.update_attributes(:company_id=>@c.id)
      get :attachment_archive_enabled, :format=>:json
      expect(response).to redirect_to request.referrer
      expect(flash[:errors].entries.size).to eq(1)
    end
  end
  describe 'show_children' do
    it "should reject if user isn't admin" do
      @u.admin = false
      @u.save!
      get :show_children, :id=> @c.id
      expect(response).to redirect_to root_path
      expect(flash[:errors].size).to eq(1)
    end
    it "should reject if user isn't in master company" do
      @u.company.update_attributes(:master=>false)
      get :show_children, :id=> @c.id
      expect(response).to redirect_to root_path
      expect(flash[:errors].size).to eq(1)
    end
    it "should split companies into linked and unlinked variables" do
      get :show_children, :id => @c.id
      expect(response).to be_success
      expect(assigns(:company)).to eq(@c)
    end
  end
  describe 'update_children' do
    it "should reject if user isn't admin" do
      @u.admin = false
      @u.save!
      post :update_children, { :id=>@c.id, :selected=>{"1"=>"50","2"=>"100"} }
      expect(response).to redirect_to root_path
      expect(flash[:errors].size).to eq(1)
    end
    it "should reject if user isn't in master company" do
      @u.company.update_attributes(:master=>false)
      post :update_children, { :id=>@c.id, :selected=>{"1"=>"50","2"=>"100"} }
      expect(response).to redirect_to root_path
      expect(flash[:errors].size).to eq(1)
    end
    it "should replace children" do
      c1 = Factory(:company)
      c2 = Factory(:company)
      c3 = Factory(:company)
      @c.linked_companies << c1
      post :update_children, { :id=>@c.id, :selected=>{"1"=>c2.id.to_s,"2"=>c3.id.to_s} }
      expect(response).to redirect_to show_children_company_path @c
      expect(Company.find(@c.id).linked_companies.to_a).to eq([c2,c3])
    end
    it "should allow user to unlink all companies" do
      c1 = Factory(:company); c2 = Factory(:company); c3 = Factory(:company)
      @c.linked_companies << c1; @c.linked_companies << c2
      post :update_children, { :id=>@c.id }
      expect(response).to redirect_to show_children_company_path @c
      expect(Company.find(@c.id).linked_companies.to_a).to eq([])
    end
  end
  describe "push_alliance_products" do
    before :each do
      MasterSetup.get.update_attributes(:custom_features=>"alliance")
      @u.admin = true
      @u.save!
      @c.update_attributes(:alliance_customer_number=>"ACNUM")
      Delayed::Job.delete_all
    end
    it "should initiate delayed_job" do
      post :push_alliance_products, :id=>@c.id
      expect(response).to redirect_to @c
      expect(flash[:notices].size).to eq(1)
      expect(flash[:errors]).to be_blank
      expect(Delayed::Job.all.size).to eq(1)
    end
    it "should push products", :disable_delayed_jobs do
      expect(OpenChain::CustomHandler::GenericAllianceProductGenerator).to receive(:sync).with(@c.id)
      post :push_alliance_products, :id=>@c.id
      expect(response).to redirect_to @c
      expect(flash[:notices].size).to eq(1)
      expect(flash[:errors]).to be_blank
      @c.reload
      expect(@c.last_alliance_product_push_at).to be > 1.minute.ago
    end
    it "should reject if alliance custom feature isn't enabled" do
      MasterSetup.get.update_attributes(:custom_features=>"")
      post :push_alliance_products, :id=>@c.id
      expect(flash[:errors].first).to eq("Cannot push file because \"alliance\" custom feature is not enabled.")
      expect(Delayed::Job.all).to be_empty
    end
    it "should reject if company doesn't have alliance customer number" do
      @c.update_attributes(:alliance_customer_number=>nil)
      post :push_alliance_products, :id=>@c.id
      expect(flash[:errors].first).to eq("Cannot push file because company doesn't have an alliance customer number.") 
      expect(Delayed::Job.all).to be_empty
    end
    it "should reject if user isn't admin" do
      @u.admin = false
      @u.save!
      post :push_alliance_products, :id=>@c.id
      expect(response).to be_redirect 
      expect(flash[:errors].size).to eq(1)
      expect(Delayed::Job.all).to be_empty
    end
    it "should reject if job was initiated less than 10 minutes ago" do
      @c.update_attributes :last_alliance_product_push_at=>1.minute.ago
      post :push_alliance_products, :id=>@c.id
      expect(flash[:errors].first).to eq("Cannot push file because last push was less than 10 minutes ago.") 
      expect(Delayed::Job.all).to be_empty
    end
  end
end
