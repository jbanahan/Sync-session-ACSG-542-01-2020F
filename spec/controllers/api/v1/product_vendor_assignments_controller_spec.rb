require 'spec_helper'

describe Api::V1::ProductVendorAssignmentsController do
  describe '#index' do
    it "should get product vendor assignments" do
      User.any_instance.stub(:view_product_vendor_assignments?).and_return(true)
      pva = Factory(:product_vendor_assignment)
      u = Factory(:master_user)
      allow_api_access u
      get :index
      expect(response).to be_success
      j = JSON.parse response.body
      expect(j['results'].collect{|r| r['id']}).to eq [pva.id]

      # foreign keys are manually added in the API
      expect(j['results'][0]['product_id']).to eq pva.product_id
      expect(j['results'][0]['vendor_id']).to eq pva.vendor_id
    end
  end
  describe '#bulk_update' do
    before :each do
      MasterSetup.get.update_attributes(vendor_management_enabled:true)
    end
    it "should update records" do
      u = Factory(:master_user)
      ProductVendorAssignment.any_instance.stub(:can_edit?).and_return true
      allow_api_access u
      cd = Factory(:custom_definition,module_type:'ProductVendorAssignment',data_type:'string')
      uid = cd.model_field_uid
      pva1 = Factory(:product_vendor_assignment)
      pva2 = Factory(:product_vendor_assignment)

      put_json = {product_vendor_assignments:[
        {uid=>'hello','id'=>pva1.id},
        {uid=>'world','id'=>pva2.id}
      ]}

      put :bulk_update, put_json
      expect(response).to be_success

      expect(pva1.get_custom_value(cd).value).to eq 'hello'
      expect(pva2.get_custom_value(cd).value).to eq 'world'
    end
    it "should fail if user cannot edit records" do
      u = Factory(:master_user)
      ProductVendorAssignment.any_instance.stub(:can_edit?).and_return false
      allow_api_access u
      cd = Factory(:custom_definition,module_type:'ProductVendorAssignment',data_type:'string')
      uid = cd.model_field_uid
      pva1 = Factory(:product_vendor_assignment)

      put_json = {product_vendor_assignments:[
        {uid=>'hello','id'=>pva1.id}
      ]}

      put :bulk_update, put_json
      expect(response).to_not be_success

      expect(pva1.get_custom_value(cd).value).to be_blank
    end
  end
end
