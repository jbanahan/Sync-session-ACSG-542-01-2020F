describe VendorsController do
  before :each do
    @u = Factory(:user)
    sign_in_as @u
  end

  describe "index" do
    it "should error if user cannot view_vendors?" do
      allow_any_instance_of(User).to receive(:view_vendors?).and_return false
      get :index
      expect(response).to be_redirect
      expect(flash[:errors].first).to match(/view/)
    end
    it "should redirect to advanced search" do
      @u.company.update_attributes(vendor:true)
      allow_any_instance_of(User).to receive(:view_vendors?).and_return true

      get :index

      expect(response.location).to match(/advanced_search/)
    end
  end

  describe "show" do
    it "should error if user cannot view company" do
      allow_any_instance_of(Company).to receive(:can_view_as_vendor?).and_return false
      get :show, id: @u.company.id.to_s
      expect(response).to be_redirect
      expect(flash[:errors].first).to match(/view/)
    end
    it "should render if user can view company" do
      allow_any_instance_of(Company).to receive(:can_view_as_vendor?).and_return true
      get :show, id: @u.company.id.to_s
      expect(response).to be_success
      expect(assigns(:company)).to eq @u.company
    end
  end

  describe "new" do
    it "should error if user cannot create_vendors" do
      allow_any_instance_of(User).to receive(:create_vendors?).and_return false
      get :new
      expect(response).to be_redirect
      expect(flash[:errors].first).to match(/create/)
    end
    it "should show if user can create_vendors" do
      allow_any_instance_of(User).to receive(:create_vendors?).and_return true
      get :new
      expect(response).to be_success
    end
  end

  describe "create" do
    it "should error if user cannot create_vendors" do
      allow_any_instance_of(User).to receive(:create_vendors?).and_return false
      expect{post :create, company:{name:'VNAME'}}.to_not change(Company,:count)
      expect(response).to be_redirect
      expect(flash[:errors].first).to match(/create/)
    end
    it "should create if user can create vendors" do
      allow_any_instance_of(User).to receive(:create_vendors?).and_return true
      expect{post :create, company:{name:'VNAME'}}.to change(Company,:count).by(1)
      c = Company.last
      expect(c.name).to eq 'VNAME'
      expect(c).to be_vendor
      expect(c.entity_snapshots.count).to eq 1
      expect(response).to redirect_to("/vendors/#{c.id}")
    end
  end

  describe "matching_vendors" do
    it "should error if user cannot view vendors" do
      allow_any_instance_of(User).to receive(:view_vendors?).and_return false

      get :matching_vendors, name:'abc'

      expect(response).to be_redirect
      expect(flash[:errors].first).to match(/view/)
    end
    it "should return matches based on first 3 characters" do
      c1 = Factory(:company,vendor:true,name:'abcxxx')
      Factory(:company,vendor:false,name:'abc') #don't match non-vendors
      Factory(:company,vendor:true,name:'xxx') #don't match non-3 letter name matches
      allow_any_instance_of(User).to receive(:view_vendors?).and_return true

      get :matching_vendors, name:'abcdefg'

      h = JSON.parse(response.body)
      expected = {'matches'=>[{'id'=>c1.id,'name'=>c1.name}]}
      expect(h).to eq expected
    end
  end

  describe "addresses" do
    it "should error if user cannot view company" do
      allow_any_instance_of(Company).to receive(:can_view_as_vendor?).and_return false
      get :addresses, id: @u.company.id.to_s
      expect(response).to be_redirect
      expect(flash[:errors].first).to match(/view/)
    end
    it "should render if user can view company" do
      allow_any_instance_of(Company).to receive(:can_view_as_vendor?).and_return true
      get :addresses, id: @u.company.id.to_s
      expect(response).to be_success
      expect(assigns(:company)).to eq @u.company
    end

  end

  describe "orders" do
    it "should error if user cannot view company" do
      allow_any_instance_of(Company).to receive(:can_view_as_vendor?).and_return false
      get :orders, id: @u.company.id.to_s
      expect(response).to be_redirect
      expect(flash[:errors].first).to match(/view/)
    end
    it "should search_secure orders" do
      allow_any_instance_of(Company).to receive(:can_view_as_vendor?).and_return true
      @u.company.update_attributes(vendor:true)
      o = Factory(:order,vendor_id:@u.company.id)
      Factory(:order) #don't find this one
      get :orders, id: @u.company.id.to_s
      expect(response).to be_success
      expect(assigns[:orders]).to eq [o]
    end
  end

  describe "survey_responses" do
    it "should error if user cannot view company" do
      allow_any_instance_of(Company).to receive(:can_view_as_vendor?).and_return false
      get :survey_responses, id: @u.company_id.to_s
      expect(response).to be_redirect
      expect(flash[:errors].first).to match(/view/)
    end
    it "should search_secure surveys" do
      allow_any_instance_of(Company).to receive(:can_view_as_vendor?).and_return true
      c = @u.company
      @u.update_attributes(survey_view:true)
      sr = Factory(:survey_response,survey:Factory(:survey,company:@u.company),base_object:c)
      sr2 = Factory(:survey_response,user:@u,base_object:c)
      Factory(:survey_response,base_object:c) #don't find this one
      get :survey_responses, id: @u.company_id.to_s
      expect(response).to be_success
      expect(assigns[:survey_responses].to_a).to eq [sr,sr2]
    end
  end

  describe "products" do
    it "should error if user cannot view company" do
      allow_any_instance_of(User).to receive(:view_products?).and_return true
      allow_any_instance_of(Company).to receive(:can_view_as_vendor?).and_return false
      get :products, id: @u.company_id.to_s
      expect(response).to be_redirect
      expect(flash[:errors].first).to match(/view/)
    end
    it "should search_secure products" do
      @u.update_attributes(product_view:true)
      @u.company.update_attributes(vendor:true)
      allow_any_instance_of(User).to receive(:view_products?).and_return true
      allow_any_instance_of(Company).to receive(:can_view_as_vendor?).and_return true
      p = Factory(:product)
      p.vendors << @u.company
      Factory(:product) #don't find this one
      get :products, id: @u.company_id.to_s
      expect(response).to be_success
      expect(assigns(:products).to_a).to eq [p]
    end
    it "should render default product view" do
      @u.update_attributes(product_view:true)
      @u.company.update_attributes(vendor:true)
      allow_any_instance_of(User).to receive(:view_products?).and_return true
      allow_any_instance_of(Company).to receive(:can_view_as_vendor?).and_return true
      p = Factory(:product)
      p.vendors << @u.company
      get :products, id: @u.company_id.to_s
      expect(response).to be_success
      expect(response).to render_template :products
    end
    it "should render custom product view" do
      CustomViewTemplate.create!(template_identifier:'vendor_products',template_path:'/custom_views/lumber_liquidators/vendors/products', module_type: "Company")
      @u.update_attributes(product_view:true)
      @u.company.update_attributes(vendor:true)
      allow_any_instance_of(User).to receive(:view_products?).and_return true
      allow_any_instance_of(Company).to receive(:can_view_as_vendor?).and_return true
      p = Factory(:product)
      p.vendors << @u.company
      get :products, id: @u.company_id.to_s
      expect(response).to be_success
      expect(response).to render_template 'custom_views/lumber_liquidators/vendors/products'
    end
  end

  describe "plants" do
    it "should error if user cannot view company" do
      allow_any_instance_of(Company).to receive(:can_view_as_vendor?).and_return false
      get :plants, id: @u.company.id.to_s
      expect(response).to be_redirect
      expect(flash[:errors].first).to match(/view/)
    end
    it "should render if user can view company" do
      allow_any_instance_of(Company).to receive(:can_view_as_vendor?).and_return true
      get :plants, id: @u.company.id.to_s
      expect(response).to be_success
      expect(assigns(:company)).to eq @u.company
    end
  end
end
