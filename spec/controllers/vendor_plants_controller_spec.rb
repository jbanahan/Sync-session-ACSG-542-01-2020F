require 'spec_helper'

describe VendorPlantsController do
  before :each do
    sign_in_as Factory(:user)
  end
  describe :show do
    it "should not show if user cannot view plant" do
      Plant.any_instance.stub(:can_view?).and_return false
      p = Factory(:plant)
      get :show, vendor_id: p.company_id, id: p.id
      expect(response).to be_redirect
      expect(flash[:errors].first).to match(/view/)
    end
    it "should show if vendor can view plant" do
      Plant.any_instance.stub(:can_view?).and_return true
      p = Factory(:plant)
      get :show, vendor_id: p.company_id, id: p.id
      expect(response).to be_success
      expect(assigns(:plant)).to eq p
    end
  end

  describe :edit do
    it "should not show if user cannot edit plant" do
      Plant.any_instance.stub(:can_edit?).and_return false
      p = Factory(:plant)
      get :edit, vendor_id: p.company_id, id: p.id
      expect(response).to be_redirect
      expect(flash[:errors].first).to match(/edit/)
    end

    it "should show if vendor can edit plant" do
      Plant.any_instance.stub(:can_edit?).and_return true
      p = Factory(:plant)
      get :edit, vendor_id: p.company_id, id: p.id
      expect(response).to be_success
      expect(assigns(:plant)).to eq p
    end
  end

  describe :update do
    it "should not update if user cannot edit plant" do
      Plant.any_instance.stub(:can_edit?).and_return false
      p = Factory(:plant,name:'original')
      expect {put :update, vendor_id: p.company_id, id: p.id, plant:{plant_name:'newname'}}.to_not change(p,:updated_at)
      expect(flash[:errors].size).to eq 1
      p.reload
      expect(p.name).to eq 'original'
    end
    it "should update if user can update plant" do
      Plant.any_instance.stub(:can_edit?).and_return true
      cd = Factory(:custom_definition,module_type:'Plant',data_type:'string')
      p = Factory(:plant)
      update_hash = {
        'plant_name'=> 'MyPlant',
        "*cf_#{cd.id}"=>'cval'
      }
      put :update, vendor_id: p.company_id, id: p.id, plant:update_hash
      expect(response).to redirect_to("/vendors/#{p.company_id}/vendor_plants/#{p.id}")
      expect(flash[:errors]).to be_blank
      expect(flash[:notices].size).to eq 1
      p.reload
      expect(p.name).to eq 'MyPlant'
      expect(p.get_custom_value(cd).value).to eq 'cval'
    end
  end

  describe :create do
    it "should not create if user cannot edit vendor" do
      Company.any_instance.stub(:can_edit?).and_return false
      c = Factory(:company)
      expect {post :create, vendor_id: c.id, plant:{plant_name:'MyPlant'}}.to_not change(Plant,:count)
      expect(response).to be_redirect
      expect(flash[:errors].size).to eq 1
    end
    it "should create and redirect to edit page" do
      Company.any_instance.stub(:can_edit?).and_return true
      c = Factory(:company)
      expect {post :create, vendor_id: c.id, plant:{plant_name:'MyPlant'}}.to change(c.plants,:count).from(0).to(1)
      expect(response).to be_redirect
      expect(flash[:notices].size).to eq 1
    end
  end

  describe :unassigned_product_groups do
    it "should error if cannot view plant" do
      Plant.any_instance.stub(:can_view?).and_return(false)
      plant = Factory(:plant)
      get :unassigned_product_groups, id: plant.id, vendor_id: plant.company_id
      expect(response).to be_redirect
      expect(flash[:errors].size).to eq 1
    end
    it "should show unassigned groups" do
      Plant.any_instance.stub(:can_view?).and_return(true)
      pg = Factory(:product_group,name:'PGX')
      plant = Factory(:plant)
      Plant.any_instance.stub(:unassigned_product_groups).and_return [pg]

      get :unassigned_product_groups, id: plant.id, vendor_id: plant.company_id

      h = JSON.parse(response.body)
      expected_response = {'product_groups'=>[{'id'=>pg.id,'name'=>'PGX'}]}
      expect(h).to eq expected_response
    end
  end

  describe :assign_product_group do
    it "should error if cannot edit plant" do
      Plant.any_instance.stub(:can_edit?).and_return false
      plant = Factory(:plant)
      pg = Factory(:product_group)
      expect{post :assign_product_group, id: plant.id, vendor_id: plant.company_id, product_group_id: pg.id}.to_not change(PlantProductGroupAssignment,:count)
      expect(response).to be_redirect
      expect(flash[:errors].size).to eq 1
    end
    it "should assign product_group" do
      Plant.any_instance.stub(:can_edit?).and_return true
      plant = Factory(:plant)
      pg = Factory(:product_group)
      expect{post :assign_product_group, id: plant.id, vendor_id: plant.company_id, product_group_id: pg.id}.
        to change(plant.plant_product_group_assignments.where(product_group_id:pg.id),:count).
          from(0).to(1)
      expected_response = {'ok'=>'ok'}
      expect(JSON.parse(response.body)).to eq expected_response
    end
  end
end
