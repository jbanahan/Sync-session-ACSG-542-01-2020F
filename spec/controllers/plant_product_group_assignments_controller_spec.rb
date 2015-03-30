require 'spec_helper'

describe PlantProductGroupAssignmentsController do
  before :each do
    sign_in_as Factory(:user)
  end
  describe :show do
    it "should show if can view" do
      ppga = Factory(:plant_product_group_assignment)
      PlantProductGroupAssignment.any_instance.stub(:can_view?).and_return true
      get :show, vendor_id: ppga.plant.company_id, vendor_plant_id: ppga.plant_id, id: ppga.id
      expect(response).to be_success
      expect(assigns(:ppga)).to eq ppga
    end
    it "shoud not show if cannot view" do
      ppga = Factory(:plant_product_group_assignment)
      PlantProductGroupAssignment.any_instance.stub(:can_view?).and_return false
      get :show, vendor_id: ppga.plant.company_id, vendor_plant_id: ppga.plant_id, id: ppga.id
      expect(response).to be_redirect
      expect(flash[:errors].size).to eq 1
    end
  end
end
