describe Api::V1::TppHtsOverridesController do
  before :each do
    @u = Factory(:user)
    allow_any_instance_of(User).to receive(:view_tpp_hts_overrides?).and_return true
    allow_any_instance_of(User).to receive(:edit_tpp_hts_overrides?).and_return true
    allow_any_instance_of(User).to receive(:view_trade_preference_programs?).and_return true
    allow_any_instance_of(TppHtsOverride).to receive(:can_view?).and_return true
    allow_any_instance_of(TppHtsOverride).to receive(:can_edit?).and_return true
    allow_api_access @u
  end
  describe '#index' do
    it 'should find overrides' do
      o = Factory(:tpp_hts_override, hts_code:'0101010101')
      get :index
      expect(response).to be_success
      h = JSON.parse(response.body)['results']
      expect(h.size).to eq 1
      expect(h[0]['tpphtso_hts_code']).to eq o.hts_code
    end
    it "should reject if user can't view" do
      allow_any_instance_of(User).to receive(:view_tpp_hts_overrides?).and_return false
      get :index
      expect(response).to_not be_success
    end
  end

  describe '#show' do
    it 'should get override' do
      o = Factory(:tpp_hts_override, hts_code:'0101010101')
      get :show, id: o.id.to_s
      expect(response).to be_success
      h = JSON.parse(response.body)
      expect(h['tpp_hts_override']['tpphtso_hts_code']).to eq o.hts_code
    end
    it "should fail if user cannot view" do
      allow_any_instance_of(TppHtsOverride).to receive(:can_view?).and_return false
      get :show, id: Factory(:tpp_hts_override).id.to_s
      expect(response).to_not be_success
    end
  end

  describe '#create' do
    let :make_hash do
      tpp = Factory(:trade_preference_program)
      {
        'tpp_hts_override'=>
        {
          'tpphtso_hts_code'=>'1234567890',
          'tpphtso_rate'=>'0.39',
          'tpphtso_note'=>'ca',
          'tpphtso_trade_preference_program_id'=>tpp.id.to_s,
          'tpphtso_start_date'=>'2016-01-01',
          'tpphtso_end_date'=>'2016-12-31'
        }
      }
    end
    it 'should create override' do
      expect {post :create, make_hash}.to change(TppHtsOverride, :count).from(0).to(1)

      expect(response).to be_success

      o = TppHtsOverride.first
      expect(o.rate).to eq BigDecimal('0.39')
      expect(o.note).to eq 'ca'
      expect(o.trade_preference_program).to_not be_nil
    end
    it 'should fail if tpp does not exist' do
      h = make_hash
      h['tpp_hts_override']['tpphtso_trade_preference_program_id'] = '999999'
      expect {post :create, h}.to_not change(TppHtsOverride, :count)

      expect(response).to_not be_success
    end
    it 'should fail if user cannot edit override' do
      allow_any_instance_of(TppHtsOverride).to receive(:can_edit?).and_return false


      expect {post :create, make_hash}.to_not change(TppHtsOverride, :count)

      expect(response).to_not be_success
    end
  end
  describe '#update' do
    before :each do
      @o = Factory(:tpp_hts_override)
      @h = {
        'id' => @o.id.to_s,
        'tpp_hts_override'=>{'id'=>@o.id.to_s, 'tpphtso_note'=>'mynote'}
      }
    end
    it 'should update' do
      put :update, @h
      @o.reload
      expect(response).to be_success
      expect(@o.note).to eq 'mynote'
    end
    it 'should fail if changing preference program' do
      old_tpp = @o.trade_preference_program
      new_tpp = Factory(:trade_preference_program)
      @h['tpp_hts_override']['tpphtso_trade_preference_program_id'] = new_tpp.id.to_s
      put :update, @h
      @o.reload
      expect(@o.trade_preference_program_id).to eq old_tpp.id
      expect(response).to_not be_success
    end
    it 'should fail if user cannot edit override' do
      allow_any_instance_of(TppHtsOverride).to receive(:can_edit?).and_return false

      put :update, @h

      @o.reload
      expect(response).to_not be_success
      expect(@o.note).to be_blank
    end
  end
end
