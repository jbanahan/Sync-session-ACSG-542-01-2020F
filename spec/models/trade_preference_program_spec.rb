require 'spec_helper'

describe TradePreferenceProgram do
  describe 'validations' do
    it 'should require origin country' do
      t = nil
      expect{t = TradePreferenceProgram.create(name:'TPP',destination_country_id:Factory(:country).id)}.to_not change(TradePreferenceProgram,:count)
      expect(t.errors[:origin_country_id]).to have(1).error
    end
    it 'should require destination country' do
      t = nil
      expect{t = TradePreferenceProgram.create(name:'TPP',origin_country_id:Factory(:country).id)}.to_not change(TradePreferenceProgram,:count)
      expect(t.errors[:destination_country_id]).to have(1).error
    end
    it 'should require name' do
      t = nil
      expect{t = TradePreferenceProgram.create(origin_country_id:Factory(:country).id,destination_country_id:Factory(:country).id)}.to_not change(TradePreferenceProgram,:count)
      expect(t.errors[:name]).to have(1).error
    end
  end
  context 'security' do
    let :prep_lane do
      tl = double(:trade_lane)
      tl.stub(:can_view?).and_return true
      tl.stub(:can_edit?).and_return true
      tl
    end
    let :prep do
      lane = prep_lane
      tpp = TradePreferenceProgram.new
      tpp.stub(:trade_lane).and_return lane
      [tpp,lane]
    end
    describe '#can_view?' do
      it 'should allow if can view associated trade lane' do
        tpp = prep.first
        expect(tpp.can_view?(double(:user))).to be_true
      end

      it 'should not allow if cannot view associated trade lane' do
        tpp, lane = prep
        lane.stub(:can_view?).and_return false
        expect(tpp.can_view?(double(:user))).to be_false
      end
    end
    describe '#can_edit?' do
      it 'should allow if can edit associated trade lane' do
        tpp = prep.first
        expect(tpp.can_edit?(double(:user))).to be_true
      end

      it 'should not allow if cannot edit associated trade lane' do
        tpp, lane = prep
        lane.stub(:can_edit?).and_return false
        expect(tpp.can_edit?(double(:user))).to be_false
      end
    end
  end
  describe '#search_secure' do
    it 'should secure if user cannot view trade lanes' do
      Factory(:trade_preference_program)
      u = double(:user)
      u.stub(:view_trade_preference_programs?).and_return false
      expect(described_class.search_secure(u,described_class).to_a).to eq []
    end
    it 'should be open if user can view trade lanes' do
      tpp = Factory(:trade_preference_program)
      u = double(:user)
      u.stub(:view_trade_preference_programs?).and_return true
      expect(described_class.search_secure(u,described_class).to_a).to eq [tpp]
    end
  end
  describe '#trade_lane' do
    it 'should return associated trade lane' do
      lane = Factory(:trade_lane)
      tpp = Factory(:trade_preference_program,origin_country:lane.origin_country,destination_country:lane.destination_country)

      expect(tpp.trade_lane).to eq lane
    end
  end
end
