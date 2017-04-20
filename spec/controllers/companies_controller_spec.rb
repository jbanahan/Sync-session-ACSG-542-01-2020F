require 'spec_helper'

describe CompaniesController do
  let (:company) { Factory(:company,:master=>true) }
  let (:user) { Factory(:user, admin: true, company: company)}
  before :each do
    sign_in_as user
  end

  describe "create" do
    it "should trigger snapshot" do
      expect{post :create, {'company'=>{'cmp_name'=>'mycompany'}}}.to change(Company,:count).by(1)
      c = Company.last
      expect(c.entity_snapshots.count).to eq 1
    end
  end
  describe "new" do
    it "renders for authorized user" do
      get :new
      expect(response).to be_success
      expect(assigns(:company)).to be_instance_of Company
      expect(assigns(:fiscal_reference_opts)).to eq([[nil, ""], [ModelField.find_by_uid(:ent_arrival_date).label, :ent_arrival_date], [ModelField.find_by_uid(:ent_first_release).label, :ent_first_release]])
    end

    it "denies access to unauthorized user" do
      company.update_attributes(master: false)
      get :new
      expect(response).to be_redirect
    end
  end
  describe "edit" do
    it "renders for authorized user" do
      get :edit, id: company
      expect(response).to be_success
      expect(assigns(:company)).to eq company
      expect(assigns(:fiscal_reference_opts)).to eq([[nil, ""], [ModelField.find_by_uid(:ent_arrival_date).label, :ent_arrival_date], [ModelField.find_by_uid(:ent_first_release).label, :ent_first_release]])
    end

    it "denies access to unauthorized user" do
      company.update_attributes(master: false)
      get :edit, id: company
      expect(response).to be_redirect
    end
  end
  describe "update" do
    it "should trigger snapshot" do
      put :update, {'id'=>company.id, 'company'=>{'cmp_name'=>'mycompany'}}
      expect(company.entity_snapshots.count).to eq 1
    end
    it "warns user if fiscal_reference has changed" do
      put :update, {'id'=>company.id, 'company'=>{'cmp_fiscal_reference'=>'release_date'}}
      expect(flash[:notices]).to include("FISCAL REFERENCE UPDATED. ENTRIES MUST BE RELOADED!")
    end
  end
  describe "attachment_archive_enabled" do
    let!(:start_date) { Date.new(2010,4,18) }
    before :each do
      company.create_attachment_archive_setup :start_date=>start_date
    end
    it "should return json for master user" do
      get :attachment_archive_enabled, :format=>:json
      expect(response).to be_success
      ary = JSON.parse response.body
      expect(ary.size).to eq(1)
      expect(ary.first['company']['name']).to eq(company.name)
      expect(ary.first['company']['id']).to eq(company.id)
      expect(Date.parse(ary.first['company']['attachment_archive_setup']['start_date'])).to eq(start_date)
      expect(ary.first['company']['attachment_archive_setup']['entry_attachments_available_count']).to eq(0)
    end
    it "should fail for non-master user" do
      company.update_attributes! master: false
      get :attachment_archive_enabled, :format=>:json
      expect(response).to redirect_to request.referrer
      expect(flash[:errors].entries.size).to eq(1)
    end
  end
  describe 'show_children' do
    it "should reject if user isn't admin" do
      user.admin = false
      user.save!
      get :show_children, :id=> company.id
      expect(response).to redirect_to root_path
      expect(flash[:errors].size).to eq(1)
    end
    it "should reject if user isn't in master company" do
      user.company.update_attributes(:master=>false)
      get :show_children, :id=> company.id
      expect(response).to redirect_to root_path
      expect(flash[:errors].size).to eq(1)
    end
    it "should split companies into linked and unlinked variables" do
      get :show_children, :id => company.id
      expect(response).to be_success
      expect(assigns(:company)).to eq(company)
    end
  end
  describe 'update_children' do
    it "should reject if user isn't admin" do
      user.admin = false
      user.save!
      post :update_children, { :id=>company.id, :selected=>{"1"=>"50","2"=>"100"} }
      expect(response).to redirect_to root_path
      expect(flash[:errors].size).to eq(1)
    end
    it "should reject if user isn't in master company" do
      user.company.update_attributes(:master=>false)
      post :update_children, { :id=>company.id, :selected=>{"1"=>"50","2"=>"100"} }
      expect(response).to redirect_to root_path
      expect(flash[:errors].size).to eq(1)
    end
    it "should replace children" do
      c1 = Factory(:company)
      c2 = Factory(:company)
      c3 = Factory(:company)
      company.linked_companies << c1
      post :update_children, { :id=>company.id, :selected=>{"1"=>c2.id.to_s,"2"=>c3.id.to_s} }
      expect(response).to redirect_to show_children_company_path company
      expect(Company.find(company.id).linked_companies.to_a).to eq([c2,c3])
    end
    it "should allow user to unlink all companies" do
      c1 = Factory(:company); c2 = Factory(:company); c3 = Factory(:company)
      company.linked_companies << c1; company.linked_companies << c2
      post :update_children, { :id=>company.id }
      expect(response).to redirect_to show_children_company_path company
      expect(Company.find(company.id).linked_companies.to_a).to eq([])
    end
  end
  describe "push_alliance_products" do
    let!(:ms) {
      ms = stub_master_setup
      allow(MasterSetup).to receive(:get).and_return ms
      ms
    }

    before :each do 
      company.update_attributes(:alliance_customer_number=>"ACNUM")
      user.admin = true
      user.save!
    end

    context "with custom feature enabled" do
      
      before :each do
        allow(ms).to receive(:custom_feature?).with("Kewill Product Push").and_return true
      end

      it "pushes products" do
        expect(OpenChain::CustomHandler::Vandegrift::KewillProductGenerator).to receive(:delay).and_return OpenChain::CustomHandler::Vandegrift::KewillProductGenerator
        expect(OpenChain::CustomHandler::Vandegrift::KewillProductGenerator).to receive(:sync).with("ACNUM")
        post :push_alliance_products, :id=>company.id
        expect(response).to redirect_to company
        expect(flash[:notices].size).to eq(1)
        expect(flash[:errors]).to be_blank

        company.reload
        expect(company.last_alliance_product_push_at).to be > 1.minute.ago
      end

      it "should reject if company doesn't have alliance customer number" do
        company.update_attributes(:alliance_customer_number=>nil)
        expect(OpenChain::CustomHandler::Vandegrift::KewillProductGenerator).not_to receive(:delay)
        post :push_alliance_products, :id=>company.id
        expect(flash[:errors].first).to eq("Cannot push file because company doesn't have an alliance customer number.") 
      end

      it "should reject if user isn't admin" do
        user.admin = false
        user.save!
        expect(OpenChain::CustomHandler::Vandegrift::KewillProductGenerator).not_to receive(:delay)
        post :push_alliance_products, :id=>company.id
        expect(response).to be_redirect 
        expect(flash[:errors].size).to eq(1)
      end
    end

    context "without custom feature" do
      before :each do
        allow(ms).to receive(:custom_feature?).with("Kewill Product Push").and_return false
      end

      it "should reject if alliance custom feature isn't enabled" do
        expect{post :push_alliance_products, :id=>company.id}.to raise_error ActionController::RoutingError
      end
    end
  end
end
