describe Api::V1::ProductRateOverridesController do
  let :make_hash do
    Factory(:country, iso_code:'CA')
    Factory(:country, iso_code:'US')
    {
      'product_rate_override'=>
      {
        'pro_rate'=>'0.39',
        'pro_notes'=>'mynotes',
        'pro_origin_cntry_iso'=>'ca',
        'pro_destination_cntry_iso'=>'us',
        'pro_start_date'=>'1900-01-01',
        'pro_end_date'=>'2099-12-31'
      }
    }
  end
  before :each do
    @u = Factory(:master_user)
    allow_api_access @u

    allow_any_instance_of(ProductRateOverride).to receive(:can_view?).and_return true
    allow_any_instance_of(ProductRateOverride).to receive(:can_edit?).and_return true
    allow_any_instance_of(User).to receive(:view_products?).and_return true
  end
  describe '#index' do
    it 'should get object' do
      pro = Factory(:product_rate_override, rate:0.21)
      get :index
      expect(response).to be_success
      h = JSON.parse(response.body)['results']
      expect(h.length).to eq 1
      expect(h[0]['id']).to eq pro.id
      expect(h[0]['pro_rate']).to eq '0.21'
    end
  end
  describe '#show' do
    it 'should get object' do
      pro = Factory(:product_rate_override, rate:0.21)
      get :show, id: pro.id.to_s
      expect(response).to be_success
      h = JSON.parse(response.body)['product_rate_override']
      expect(h['id']).to eq pro.id
    end
    it 'should not get object without permission' do
      allow_any_instance_of(ProductRateOverride).to receive(:can_view?).and_return false
      pro = Factory(:product_rate_override, rate:0.21)
      get :show, id: pro.id.to_s
      expect(response).to_not be_success
    end
  end
  describe '#update' do
    it 'should update object' do
      pro = Factory(:product_rate_override, rate:0.21)
      h = make_hash
      h['id'] = pro.id.to_s
      h['product_rate_override']['id'] = h['id']
      put :update, h
      expect(response).to be_success
      pro.reload
      expect(pro.origin_country.iso_code).to eq 'CA'
      expect(pro.destination_country.iso_code).to eq 'US'
      expect(pro.rate).to eq 0.39
      expect(pro.notes).to eq 'mynotes'
    end
    it 'should not update object without permission' do
      allow_any_instance_of(ProductRateOverride).to receive(:can_edit?).and_return false
      pro = Factory(:product_rate_override, rate:0.21)
      h = make_hash
      h['id'] = pro.id.to_s
      h['product_rate_override']['id'] = h['id']
      put :update, h
      expect(response).to_not be_success
      pro.reload
      expect(pro.rate).to eq 0.21
    end
  end
  describe '#create' do
    before :each do
      @p = Factory(:product)
      @h = make_hash
      @h['product_rate_override']['pro_product_id'] = @p.id.to_s
    end
    it 'should create object' do
      expect {post :create, @h}.to change(ProductRateOverride, :count).from(0).to(1)
      expect(response).to be_success
      pro = ProductRateOverride.first
      expect(pro.origin_country.iso_code).to eq 'CA'
      expect(pro.destination_country.iso_code).to eq 'US'
      expect(pro.rate).to eq 0.39
      expect(pro.notes).to eq 'mynotes'
    end
    it 'should not create object without permission' do
      allow_any_instance_of(ProductRateOverride).to receive(:can_edit?).and_return false
      expect {post :create, @h}.to_not change(ProductRateOverride, :count)
      expect(response).to_not be_success
    end

  end
end
