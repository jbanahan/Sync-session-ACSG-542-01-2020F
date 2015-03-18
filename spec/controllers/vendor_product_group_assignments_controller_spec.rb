require 'spec_helper'

describe VendorProductGroupAssignmentsController do
  before :each do
    sign_in_as Factory(:user)
  end
  describe :show do
    it "should error if cannot view" do
      VendorProductGroupAssignment.any_instance.stub(:can_view?).and_return false
      vpga = Factory(:vendor_product_group_assignment)

      get :show, id: vpga.id.to_s

      expect(response).to be_redirect
      expect(flash[:errors].first).to match(/view/)
    end
    it "should render" do
      VendorProductGroupAssignment.any_instance.stub(:can_view?).and_return true
      vpga = Factory(:vendor_product_group_assignment)

      get :show, id: vpga.id.to_s

      expect(response).to be_success
      expect(assigns(:vpga)).to eq vpga
    end
  end
end
