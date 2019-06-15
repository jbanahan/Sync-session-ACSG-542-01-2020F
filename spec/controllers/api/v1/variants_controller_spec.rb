describe Api::V1::VariantsController do
  before :each do
    @u = Factory(:user)
    allow_api_access @u
  end
  describe '#show' do
    before :each do
      @v = Factory(:variant,variant_identifier:'v123')
    end
    it 'should show if user can view variant' do
      expect_any_instance_of(Variant).to receive(:can_view?).with(@u).and_return true
      get :show, id: @v.id
      expect(response).to be_success

      h = JSON.parse(response.body)['variant']
      expect(h['var_identifier']).to eq @v.variant_identifier
    end
    it 'should not show if users cannot view variant' do
      expect_any_instance_of(Variant).to receive(:can_view?).with(@u).and_return false
      get :show, id: @v.id
      expect(response.status).to eq 404
    end
  end
  describe '#for_vendor_product' do
    it "should return active variant assigned to vendor's plant that user can view" do
      product = Factory(:product)
      plant = Factory(:plant)
      c = plant.company
      v1 = Factory(:variant,product:product)

      # this one won't return because user cannot view it
      v2 = Factory(:variant,product:product)

      # this one won't return because it's not associated with the company
      Factory(:variant,product:product)

      [v1,v2].each { |v| plant.plant_variant_assignments.create!(variant:v)}

      allow_any_instance_of(Variant).to receive(:can_view?) do |inst|
        inst!=v2
      end

      allow_any_instance_of(Company).to receive(:can_view?).and_return true
      allow_any_instance_of(Product).to receive(:can_view?).and_return true

      get :for_vendor_product, vendor_id: c.id.to_s, product_id: product.id.to_s

      expect(response).to be_success
      h = JSON.parse(response.body)['variants']
      expect(h.length).to eq 1
      expect(h[0]['id']).to eq v1.id
    end
    it "should fail if user cannot view company" do
      product = Factory(:product)
      c = Factory(:company)

      allow_any_instance_of(Company).to receive(:can_view?).and_return false
      allow_any_instance_of(Product).to receive(:can_view?).and_return true

      get :for_vendor_product, vendor_id: c.id.to_s, product_id: product.id.to_s

      expect(response.status).to eq 404
    end
    it "should fail if user cannot view product" do
      product = Factory(:product)
      c = Factory(:company)

      allow_any_instance_of(Company).to receive(:can_view?).and_return true
      allow_any_instance_of(Product).to receive(:can_view?).and_return false

      get :for_vendor_product, vendor_id: c.id.to_s, product_id: product.id.to_s

      expect(response.status).to eq 404
    end
  end
end
