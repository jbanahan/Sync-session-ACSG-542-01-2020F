require 'spec_helper'

describe ChargeCodesController do
  before :each do
    @u = Factory(:user,:admin=>true,:company=>Factory(:company,:master=>true))
    activate_authlogic
    UserSession.create! @u
  end
  describe :index do
    it "should only allow admins" do
      @u.admin = false
      @u.save!
      get :index
      response.should be_redirect
      flash[:errors].should have(1).message
    end
    it "should show all charge codes" do
      3.times {|i| ChargeCode.create!(:code=>"#{5-i}")}
      get :index
      c = assigns[:charge_codes]
      c.should have(3).codes
      c.first.code.should == "3"
    end
  end

  describe :create do
    it "should only allow admins" do
      @u.admin = false
      @u.save!
      post :create, {'charge_code'=> {'code'=>"x",'description'=>"y"} }
      response.should be_redirect
      flash[:errors].should have(1).message
    end
    it "should create charge code" do
      post :create, {'charge_code'=> {'code'=>"x",'description'=>"y"} }
      response.should redirect_to charge_codes_path
      c = ChargeCode.first
      c.code.should == "x"
      c.description.should == "y"
    end
  end

  describe :destroy do
    before :each do
      @c = ChargeCode.create!(:code=>"a")
    end
    it "should only allow admins" do
      @u.admin = false
      @u.save!
      delete :destroy, :id=>@c.id
      response.should be_redirect
      flash[:errors].should have(1).message
    end
    it "should destroy charge code" do
      delete :destroy, :id=>@c.id
      response.should be_redirect
      flash[:notices].should have(1).message
    end
  end

  describe :update do
    before :each do
      @c = ChargeCode.create!(:code=>"a")
    end
    it "should only allow admins" do
      @u.admin = false
      @u.save!
      put :update, { :id=>@c.id, 'charge_code'=>{'code'=>'b','description'=>'xyz'} }
      response.should be_redirect
      flash[:errors].should have(1).message
      ChargeCode.find(@c.id).code.should == "a"
    end
    it "should update charge code" do
      put :update, { :id=>@c.id, 'charge_code'=>{'code'=>'b','description'=>'xyz'} }
      response.should be_redirect
      flash[:notices].should have(1).message
      ChargeCode.find(@c.id).code.should == "b"
    end
  end

end
