require 'spec_helper'

describe Customer::LumberLiquidatorsController do
  before :each do
    @user = Factory(:user)
    sign_in_as @user
  end
  describe :sap_vendor_setup_form do
    before :each do
      @vendor = Factory(:company,vendor:true)
      Company.any_instance.stub(:can_view_as_vendor?).and_return(true)
    end
    it "should 404 if no 'Lumber SAP' custom feature" do
      expect{get :sap_vendor_setup_form, vendor_id: @vendor.id}.to raise_error ActionController::RoutingError
    end
    it "should render if 'Lumber SAP' custom feature" do
      MasterSetup.get.update_attributes(custom_features:'Lumber SAP')
      get :sap_vendor_setup_form, vendor_id: @vendor.id
      expect(response).to be_success
    end
  end
end