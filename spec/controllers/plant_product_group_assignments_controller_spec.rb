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

  describe :update do
    before :each do
      @cd = Factory(:custom_definition,module_type:'PlantProductGroupAssignment',data_type:'text')
      @ppga = Factory(:plant_product_group_assignment)
      @h = {"*cf_#{@cd.id}"=>'myval'}
    end
    it "should update if can edit" do
      PlantProductGroupAssignment.any_instance.stub(:can_edit?).and_return true
      post :update, vendor_id: @ppga.plant.company_id, vendor_plant_id:@ppga.plant_id, id: @ppga.id, plant_product_group_assignment: @h
      expect(response).to be_redirect
      @ppga.reload
      expect(@ppga.get_custom_value(@cd).value).to eq 'myval'
    end
    it "should not update if cannot edit" do
      PlantProductGroupAssignment.any_instance.stub(:can_edit?).and_return false
      post :update, vendor_id: @ppga.plant.company_id, vendor_plant_id:@ppga.plant_id, id: @ppga.id, plant_product_group_assignment: @h
      expect(response).to be_redirect
      @ppga.reload
      expect(@ppga.get_custom_value(@cd).value).to be_blank
    end
  end
end
