require 'spec_helper'

describe Api::V1::TradePreferenceProgramsController do
  let :prep_countries do
    us = Factory(:country,iso_code:'US')
    ca = Factory(:country,iso_code:'CA')
    [us,ca]
  end
  before :each do
    @u = Factory(:user)
    allow_any_instance_of(User).to receive(:view_trade_preference_programs?).and_return true
    allow_any_instance_of(User).to receive(:edit_trade_preference_programs?).and_return true
    allow_any_instance_of(TradePreferenceProgram).to receive(:can_view?).and_return true
    allow_any_instance_of(TradePreferenceProgram).to receive(:can_edit?).and_return true
    allow_any_instance_of(TradePreferenceProgram).to receive(:can_comment?).and_return true
    allow_any_instance_of(TradePreferenceProgram).to receive(:can_attach?).and_return true
    allow_api_access @u
  end
  describe '#index' do
    it 'should find tpps' do
      us, ca = prep_countries
      Factory(:trade_preference_program,origin_country:us,destination_country:ca)
      Factory(:trade_preference_program,origin_country:ca,destination_country:us)

      get :index


      expect(response).to be_success
      h = JSON.parse(response.body)['results']
      expect(h.size).to eq 2
      expect(h[0]['tpp_origin_cntry_iso']).to eq 'US'
      expect(h[0]['tpp_destination_cntry_iso']).to eq 'CA'
      expect(h[1]['tpp_origin_cntry_iso']).to eq 'CA'
      expect(h[1]['tpp_destination_cntry_iso']).to eq 'US'
    end
    it 'should fail if user cannot view_trade_preference_programs?' do
      allow_any_instance_of(User).to receive(:view_trade_preference_programs?).and_return false
      get :index
      expect(response).to_not be_success
    end
  end

  describe '#show' do
    it 'should find tpp' do
      tpp = Factory(:trade_preference_program)

      get :show, id: tpp.id.to_s

      expect(response).to be_success

      expect(JSON.parse(response.body)['trade_preference_program']['id']).to eq tpp.id
    end
    it 'should fail if user cannot view tpp' do
      allow_any_instance_of(TradePreferenceProgram).to receive(:can_view?).and_return false
      get :show, id: Factory(:trade_preference_program).id.to_s
      expect(response).to_not be_success
    end
  end

  describe '#create' do
    let :make_hash do
      {
        'trade_preference_program'=>
        {
          'tpp_name'=>'ABC',
          'tpp_tariff_adjustment_percentage'=>'0.39',
          'tpp_origin_cntry_iso'=>'ca',
          'tpp_destination_cntry_iso'=>'us'
        }
      }
    end
    it 'should create tpp' do
      us, ca = prep_countries

      expect{post :create, make_hash}.to change(TradePreferenceProgram,:count).from(0).to(1)

      expect(response).to be_success

      tpp = TradePreferenceProgram.first
      expect(tpp.tariff_adjustment_percentage).to eq BigDecimal('0.39')
      expect(tpp.origin_country).to eq ca
      expect(tpp.destination_country).to eq us
    end
    it 'should fail if user cannot edit tpps' do
      allow_any_instance_of(TradePreferenceProgram).to receive(:can_edit?).and_return false

      prep_countries

      expect{post :create, make_hash}.to_not change(TradePreferenceProgram,:count)

      expect(response).to_not be_success
    end
  end

  describe '#update' do
    let :data_prep do
      prep_countries
      tpp = Factory(:trade_preference_program)
      h = {
        'id' => tpp.id.to_s,
        'trade_preference_program'=>
        {
          'id' => tpp.id.to_s,
          'tpp_tariff_adjustment_percentage'=>'0.39',
          'tpp_origin_cntry_iso'=>'ca',
          'tpp_destination_cntry_iso'=>'us'
        }
      }
      [tpp,h]
    end
    it 'should update tpp' do
      tpp, hash = data_prep

      put :update, hash

      expect(response).to be_success

      tpp.reload
      expect(tpp.tariff_adjustment_percentage).to eq BigDecimal('0.39')
    end
    it 'should fail if user cannot edit tpp' do
      allow_any_instance_of(TradePreferenceProgram).to receive(:can_edit?).and_return false
      tpp, hash = data_prep

      put :update, hash

      expect(response).to_not be_success

      tpp.reload
      expect(tpp.tariff_adjustment_percentage).to be_blank

    end
  end
end
