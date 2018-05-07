require 'spec_helper'

describe PortsController do
  before :each do
    @u = Factory(:admin_user)

    sign_in_as @u
  end
  
  describe "index" do
    it "should only allow admins" do
      @u.admin = false
      @u.save!
      get :index
      expect(response).to be_redirect
      expect(flash[:errors].size).to eq(1)
    end

    it "should show ports" do
      3.times {|i| Port.create!(:name=>"p#{i}")}
      get :index
      expect(assigns[:ports].size).to eq(3)
      expect(assigns[:ports].first.name).to eq("p0")
    end

  end
  describe "create" do
    it "should only allow admins" do
      @u.admin = false
      @u.save!
      post :create, {'port'=>{'name'=>'x'}}
      expect(response).to be_redirect
      expect(flash[:errors].size).to eq(1)
      expect(Port.all).to be_empty
    end
    it "should create port" do
      post :create, {'port'=>{'name'=>'x'}}
      expect(response).to be_redirect
      p = Port.first
      expect(p.name).to eq('x')
    end
  end

  describe "destroy" do
    before :each do 
       @p = Factory(:port)
    end
    it "should only allow admins" do
      @u.admin = false
      @u.save!
      delete :destroy, :id=>@p.id
      expect(response).to be_redirect
      expect(flash[:errors].size).to eq(1)
    end
    it "should destroy port" do
      delete :destroy, :id=>@p.id
      expect(response).to be_redirect
      expect(flash[:notices].size).to eq(1)
      expect(Port.all).to be_empty
    end
  end

  describe "update" do
    before :each do 
      @p = Factory(:port, name: 'old name', unlocode: "LOCOD", schedule_d_code: "1234", schedule_k_code: "12345", cbsa_port: "9876")
    end

    it "should only allow admins" do
      @u.admin = false
      @u.save!
      put :update, { :id=>@p.id, 'port'=>{'name'=>'my port'} }
      expect(response).to be_redirect
      expect(flash[:errors].size).to eq(1)
      @p.reload
      expect(@p.name).to eq('old name')
    end

    it "should update port" do
      put :update, { :id=>@p.id, 'port'=>{'name'=>'my port'} }
      expect(response).to be_redirect
      expect(flash[:notices].size).to eq(1)
      @p.reload
      expect(@p.name).to eq('my port')
    end

    it "nulls blank parameter values" do
      put :update, { :id=>@p.id, 'port'=>{'schedule_k_code'=>' ', 'schedule_d_code'=>' ', 'unlocode'=>' ', 'cbsa_port'=>' '} }
      @p.reload
      expect(flash[:errors]).to be_blank
      expect(@p.schedule_k_code).to be_nil
      expect(@p.schedule_d_code).to be_nil
      expect(@p.unlocode).to be_nil
      expect(@p.cbsa_port).to be_nil
    end
  end
end
