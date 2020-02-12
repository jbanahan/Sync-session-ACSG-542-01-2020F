describe Customer::LumberLiquidatorsController do
  before :each do
    @user = Factory(:user)
    sign_in_as @user
  end
  describe "sap_vendor_setup_form" do

    let! (:master_setup) {
      ms = stub_master_setup
      allow(ms).to receive(:custom_feature?).and_return false
      ms
    }

    before :each do
      @vendor = Factory(:company,vendor:true)
      allow_any_instance_of(Company).to receive(:can_view_as_vendor?).and_return(true)
    end
    it "should 404 if no 'Lumber SAP' custom feature" do
      expect{get :sap_vendor_setup_form, vendor_id: @vendor.id}.to raise_error ActionController::RoutingError
    end
    it "should render if 'Lumber SAP' custom feature" do
      expect(master_setup).to receive(:custom_feature?).with('Lumber SAP').and_return true
      get :sap_vendor_setup_form, vendor_id: @vendor.id
      expect(response).to be_success
    end
  end
end
