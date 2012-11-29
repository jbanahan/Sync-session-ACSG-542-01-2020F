require 'spec_helper'

describe ChargeCategoriesController do

  before :each do
    @c = Factory(:company)
    @cat = @c.charge_categories.create!(:charge_code=>'A',:category=>'B')
    activate_authlogic
  end
  describe "index" do
    it "should require user to be admin" do
      UserSession.create! Factory(:user)
      get :index, :company_id=>@c.id
      response.should redirect_to request.referrer
      flash[:errors].should have(1).message
    end
    it "should get charge categories for given company" do
      UserSession.create! Factory(:admin_user)
      get :index, :company_id=>@c.id
      response.should be_success
      assigns(:charge_categories).to_a.should == [@cat]
    end
  end

  describe "create" do
    it "should require user to be admin" do
      UserSession.create! Factory(:user)
      post :create, :company_id=>@c.id, 'charge_category'=>{'charge_code'=>'x','category'=>'y'}
      response.should redirect_to request.referrer
      flash[:errors].should have(1).message
      @c.reload
      @c.should have(1).charge_categories
    end
    it "should create category" do
      UserSession.create! Factory(:admin_user)
      post :create, :company_id=>@c.id, 'charge_category'=>{'charge_code'=>'x','category'=>'y'}
      response.should redirect_to company_charge_categories_path(@c)
      flash[:notices].first.should == "Charge Category created successfully."
      @c.reload
      @c.should have(2).charge_categories
      @c.charge_categories.where(:charge_code=>'x').where(:category=>'y').to_a.should have(1).item
    end
  end

  describe "destroy" do
    it "should require user to be admin" do
      UserSession.create! Factory(:user)
      delete :destroy, :company_id=>@c.id, :id=>@cat.id
      response.should redirect_to request.referrer
      flash[:errors].should have(1).message
      @c.reload
      @c.should have(1).charge_categories
    end 
    it "should destroy category" do
      UserSession.create! Factory(:admin_user)
      delete :destroy, :company_id=>@c.id, :id=>@cat.id
      response.should redirect_to company_charge_categories_path(@c)
      flash[:notices].first.should == "Charge Category deleted."
      ChargeCategory.all.should be_empty
    end
  end

end
