describe Api::V1::TradeLanesController do
  let :prep_countries do
    us = create(:country, iso_code:'US')
    ca = create(:country, iso_code:'CA')
    [us, ca]
  end
  before :each do
    @u = create(:user)
    allow_any_instance_of(User).to receive(:view_trade_lanes?).and_return true
    allow_any_instance_of(User).to receive(:edit_trade_lanes?).and_return true
    allow_api_access @u
  end
  describe '#index' do
    it 'should find trade lanes' do
      us, ca = prep_countries
      create(:trade_lane, origin_country:us, destination_country:ca)
      create(:trade_lane, origin_country:ca, destination_country:us)

      get :index


      expect(response).to be_success
      h = JSON.parse(response.body)['results']
      expect(h.size).to eq 2
      expect(h[0]['lane_origin_cntry_iso']).to eq 'US'
      expect(h[0]['lane_destination_cntry_iso']).to eq 'CA'
      expect(h[1]['lane_origin_cntry_iso']).to eq 'CA'
      expect(h[1]['lane_destination_cntry_iso']).to eq 'US'
    end
    it 'should fail if user cannot view_trade_lanes?' do
      allow_any_instance_of(User).to receive(:view_trade_lanes?).and_return false
      get :index
      expect(response).to_not be_success
    end
  end

  describe '#show' do
    it 'should find trade lane' do
      tl = create(:trade_lane)

      get :show, id: tl.id.to_s

      expect(response).to be_success

      expect(JSON.parse(response.body)['trade_lane']['id']).to eq tl.id
    end
    it 'should fail if user cannot view trade lane' do
      allow_any_instance_of(User).to receive(:view_trade_lanes?).and_return false
      get :show, id: create(:trade_lane).id.to_s
      expect(response).to_not be_success
    end
  end

  describe '#create' do
    let :make_hash do
      {
        'trade_lane'=>
        {
          'lane_tariff_adjustment_percentage'=>'0.39',
          'lane_notes'=>'mynotes',
          'lane_origin_cntry_iso'=>'ca',
          'lane_destination_cntry_iso'=>'us'
        }
      }
    end
    it 'should create trade lane' do
      us, ca = prep_countries

      expect {post :create, make_hash}.to change(TradeLane, :count).from(0).to(1)

      expect(response).to be_success

      tl = TradeLane.first
      expect(tl.tariff_adjustment_percentage).to eq BigDecimal('0.39')
      expect(tl.notes).to eq 'mynotes'
      expect(tl.origin_country).to eq ca
      expect(tl.destination_country).to eq us
    end
    it 'should fail if user cannot edit trade lanes' do
      allow_any_instance_of(User).to receive(:edit_trade_lanes?).and_return false

      prep_countries

      expect {post :create, make_hash}.to_not change(TradeLane, :count)

      expect(response).to_not be_success
    end
  end

  describe '#update' do
    let :data_prep do
      prep_countries
      tl = create(:trade_lane)
      h = {
        'id' => tl.id.to_s,
        'trade_lane'=>
        {
          'id' => tl.id.to_s,
          'lane_tariff_adjustment_percentage'=>'0.39',
          'lane_notes'=>'mynotes',
          'lane_origin_cntry_iso'=>'ca',
          'lane_destination_cntry_iso'=>'us'
        }
      }
      [tl, h]
    end
    it 'should update trade lane' do
      lane, hash = data_prep

      put :update, hash

      expect(response).to be_success

      lane.reload
      expect(lane.notes).to eq 'mynotes'
    end
    it 'should fail if user cannot edit trade lane' do
      allow_any_instance_of(User).to receive(:edit_trade_lanes?).and_return false
      lane, hash = data_prep

      put :update, hash

      expect(response).to_not be_success

      lane.reload
      expect(lane.notes).to be_blank

    end
  end
end
