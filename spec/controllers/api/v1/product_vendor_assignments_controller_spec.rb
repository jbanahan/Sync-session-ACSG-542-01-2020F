describe Api::V1::ProductVendorAssignmentsController do
  describe '#index' do
    it "should get product vendor assignments" do
      allow_any_instance_of(User).to receive(:view_product_vendor_assignments?).and_return(true)
      pva = FactoryBot(:product_vendor_assignment)
      u = FactoryBot(:master_user)
      allow_api_access u
      get :index
      expect(response).to be_success
      j = JSON.parse response.body
      expect(j['results'].collect {|r| r['id']}).to eq [pva.id]

      # foreign keys are manually added in the API
      expect(j['results'][0]['product_id']).to eq pva.product_id
      expect(j['results'][0]['vendor_id']).to eq pva.vendor_id
    end
  end
  describe '#show' do
    it 'should get record' do
      allow_any_instance_of(User).to receive(:view_product_vendor_assignments?).and_return(true)
      pva = FactoryBot(:product_vendor_assignment)
      u = FactoryBot(:master_user)
      allow_api_access u
      get :show, id: pva.id.to_s
      expect(response).to be_success
      j = JSON.parse response.body
      expect(j['product_vendor_assignment']['product_id']).to eq pva.product_id
    end
  end
  describe '#update' do
    it 'should update record' do
      allow_any_instance_of(User).to receive(:view_product_vendor_assignments?).and_return(true)
      allow_any_instance_of(ProductVendorAssignment).to receive(:can_edit?).and_return(true)
      cd = FactoryBot(:custom_definition, module_type:'ProductVendorAssignment', data_type:'string')
      pva = FactoryBot(:product_vendor_assignment)
      u = FactoryBot(:master_user)
      allow_api_access u
      h = {'id'=>pva.id, "*cf_#{cd.id}"=>'hello'}
      put :update, id: pva.id.to_s, product_vendor_assignment:h
      expect(response).to be_success
      pva.reload
      expect(pva.get_custom_value(cd).value).to eq 'hello'
    end
  end
  describe '#bulk_create' do

    let! (:master_setup) {
      ms = stub_master_setup
      allow(ms).to receive(:vendor_management_enabled?).and_return true
      ms
    }

    before :each do
      @u = FactoryBot(:master_user)
      allow_api_access @u
    end
    it "should create records by IDs" do
      allow_any_instance_of(Company).to receive(:can_edit?).and_return true
      allow_any_instance_of(Product).to receive(:can_edit?).and_return true
      allow_any_instance_of(ProductVendorAssignment).to receive(:can_edit?).and_return true
      cd = FactoryBot(:custom_definition, module_type:'ProductVendorAssignment', data_type:'string')

      v1 = FactoryBot(:company, vendor:true)
      v2 = FactoryBot(:company, vendor:true)

      p1 = FactoryBot(:product)
      p2 = FactoryBot(:product)

      request_hash = {
        product_ids:[p1.id, p2.id],
        vendor_ids:[v1.id, v2.id],
        product_vendor_assignment:{cd.model_field_uid=>'Hello'}
      }

      expect {post :bulk_create, request_hash}.to change(ProductVendorAssignment, :count).from(0).to(4)
      expect(response).to be_success
      expect(JSON.parse(response.body)['messages']).to eq ['4 product / vendor assignments created.']

      expect_to_find = [
        [v1.id, p1.id],
        [v1.id, p2.id],
        [v2.id, p1.id],
        [v2.id, p2.id]
      ]
      ProductVendorAssignment.all.each do |pva|
        expect_to_find.delete [pva.vendor_id, pva.product_id]
        expect(pva.get_custom_value(cd).value).to eq 'Hello'
      end
      expect(expect_to_find).to be_empty
    end
    it "should create by unique identifiers" do
      allow_any_instance_of(Company).to receive(:can_edit?).and_return true
      allow_any_instance_of(Product).to receive(:can_edit?).and_return true
      allow_any_instance_of(ProductVendorAssignment).to receive(:can_edit?).and_return true
      cd = FactoryBot(:custom_definition, module_type:'ProductVendorAssignment', data_type:'string')

      v1 = FactoryBot(:company, vendor:true, system_code:'X')
      v2 = FactoryBot(:company, vendor:true, system_code:'Y')

      p1 = FactoryBot(:product)
      p2 = FactoryBot(:product)

      request_hash = {
        prod_uids:[p1.unique_identifier, p2.unique_identifier],
        cmp_sys_codes:[v1.system_code, v2.system_code],
        product_vendor_assignment:{cd.model_field_uid=>'Hello'}
      }

      expect_to_find = [
        [v1.id, p1.id],
        [v1.id, p2.id],
        [v2.id, p1.id],
        [v2.id, p2.id]
      ]
      expect {post :bulk_create, request_hash}.to change(ProductVendorAssignment, :count).from(0).to(4)
      expect(response).to be_success
      expect(JSON.parse(response.body)['messages']).to eq ['4 product / vendor assignments created.']

      ProductVendorAssignment.all.each do |pva|
        expect_to_find.delete [pva.vendor_id, pva.product_id]
        expect(pva.get_custom_value(cd).value).to eq 'Hello'
      end
      expect(expect_to_find).to be_empty
    end
    it "should not create if user cannot edit product" do
      allow_any_instance_of(Company).to receive(:can_edit?).and_return true
      allow_any_instance_of(Product).to receive(:can_edit?).and_return false
      allow_any_instance_of(ProductVendorAssignment).to receive(:can_edit?).and_return true

      v1 = FactoryBot(:company, vendor:true, system_code:'X')

      p1 = FactoryBot(:product)

      request_hash = {
        prod_uids:[p1.unique_identifier],
        cmp_sys_codes:[v1.system_code]
      }

      expect {post :bulk_create, request_hash}.to_not change(ProductVendorAssignment, :count)
      expect(response).to_not be_success
    end
    it "should not create if user cannot edit vendor" do
      allow_any_instance_of(Company).to receive(:can_edit?).and_return false
      allow_any_instance_of(Product).to receive(:can_edit?).and_return true
      allow_any_instance_of(ProductVendorAssignment).to receive(:can_edit?).and_return true

      v1 = FactoryBot(:company, vendor:true, system_code:'X')

      p1 = FactoryBot(:product)

      request_hash = {
        prod_uids:[p1.unique_identifier],
        cmp_sys_codes:[v1.system_code]
      }

      expect {post :bulk_create, request_hash}.to_not change(ProductVendorAssignment, :count)
      expect(response).to_not be_success
    end
    it "should report records not found but should not fail" do
      allow_any_instance_of(Company).to receive(:can_edit?).and_return true
      allow_any_instance_of(Product).to receive(:can_edit?).and_return true
      allow_any_instance_of(ProductVendorAssignment).to receive(:can_edit?).and_return true

      v1 = FactoryBot(:company, vendor:true, system_code:'X')

      p1 = FactoryBot(:product)

      request_hash = {
        prod_uids:[p1.unique_identifier, 'otherproduct'],
        cmp_sys_codes:[v1.system_code]
      }

      expect {post :bulk_create, request_hash}.to change(ProductVendorAssignment, :count).from(0).to(1)
      expect(response).to be_success

      expect(JSON.parse(response.body)['messages']).to eq [
        "Products with #{ModelField.find_by_uid(:prod_uid).label} \"otherproduct\" not found.",
        '1 product / vendor assignments created.'
      ]
    end
    it "should fail if more than 100 records requested" do
      allow_any_instance_of(Company).to receive(:can_edit?).and_return true
      allow_any_instance_of(Product).to receive(:can_edit?).and_return true
      allow_any_instance_of(ProductVendorAssignment).to receive(:can_edit?).and_return true

      v1 = FactoryBot(:company, vendor:true, system_code:'X')

      p1 = FactoryBot(:product)

      product_uids = Array.new(11, 'x')
      product_uids << p1.unique_identifier
      cmp_codes = Array.new(11, 'y')
      cmp_codes << v1.system_code
      request_hash = {
        prod_uids:product_uids,
        cmp_sys_codes:cmp_codes
      }

      expect {post :bulk_create, request_hash}.to_not change(ProductVendorAssignment, :count)
      expect(response).to_not be_success
    end
  end
  describe '#bulk_update' do

    let! (:master_setup) {
      ms = stub_master_setup
      allow(ms).to receive(:vendor_management_enabled?).and_return true
      ms
    }

    it "should update records" do
      u = FactoryBot(:master_user)
      allow_any_instance_of(ProductVendorAssignment).to receive(:can_edit?).and_return true
      allow_api_access u
      cd = FactoryBot(:custom_definition, module_type:'ProductVendorAssignment', data_type:'string')
      uid = cd.model_field_uid
      pva1 = FactoryBot(:product_vendor_assignment)
      pva2 = FactoryBot(:product_vendor_assignment)

      put_json = {product_vendor_assignments:[
        {uid=>'hello', 'id'=>pva1.id},
        {uid=>'world', 'id'=>pva2.id}
      ]}

      put :bulk_update, put_json
      expect(response).to be_success

      expect(pva1.get_custom_value(cd).value).to eq 'hello'
      expect(pva2.get_custom_value(cd).value).to eq 'world'
    end
    it "should fail if user cannot edit records" do
      u = FactoryBot(:master_user)
      allow_any_instance_of(ProductVendorAssignment).to receive(:can_edit?).and_return false
      allow_api_access u
      cd = FactoryBot(:custom_definition, module_type:'ProductVendorAssignment', data_type:'string')
      uid = cd.model_field_uid
      pva1 = FactoryBot(:product_vendor_assignment)

      put_json = {product_vendor_assignments:[
        {uid=>'hello', 'id'=>pva1.id}
      ]}

      put :bulk_update, put_json
      expect(response).to_not be_success

      expect(pva1.get_custom_value(cd).value).to be_blank
    end
  end
end
