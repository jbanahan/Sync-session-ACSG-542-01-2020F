require 'spec_helper'

describe PortsController do
  before :each do
    @u = Factory(:admin_user)

    sign_in_as @u
  end
  
  describe :index do
    it "should only allow admins" do
      @u.admin = false
      @u.save!
      get :index
      response.should be_redirect
      flash[:errors].should have(1).message
    end

    it "should show ports" do
      3.times {|i| Port.create!(:name=>"p#{i}")}
      get :index
      assigns[:ports].should have(3).ports
      assigns[:ports].first.name.should == "p0"
    end

  end
  describe :create do
    it "should only allow admins" do
      @u.admin = false
      @u.save!
      post :create, {'port'=>{'name'=>'x'}}
      response.should be_redirect
      flash[:errors].should have(1).message
      Port.all.should be_empty
    end
    it "should create port" do
      post :create, {'port'=>{'name'=>'x'}}
      response.should be_redirect
      p = Port.first
      p.name.should == 'x'
    end
  end

  describe :destroy do
    before :each do 
       @p = Factory(:port)
    end
    it "should only allow admins" do
      @u.admin = false
      @u.save!
      delete :destroy, :id=>@p.id
      response.should be_redirect
      flash[:errors].should have(1).message
    end
    it "should destroy port" do
      delete :destroy, :id=>@p.id
      response.should be_redirect
      flash[:notices].should have(1).message
      Port.all.should be_empty
    end
  end

  describe :update do
    before :each do 
      @p = Factory(:port,:name=>'old name')
    end

    it "should only allow admins" do
      @u.admin = false
      @u.save!
      put :update, { :id=>@p.id, 'port'=>{'name'=>'my port'} }
      response.should be_redirect
      flash[:errors].should have(1).message
      @p.reload
      @p.name.should == 'old name'
    end
    it "should update port" do
      put :update, { :id=>@p.id, 'port'=>{'name'=>'my port'} }
      response.should be_redirect
      flash[:notices].should have(1).message
      @p.reload
      @p.name.should == 'my port'
    end
  end
end
