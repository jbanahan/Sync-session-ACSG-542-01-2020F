describe TradePreferenceProgram do
  context 'validations' do
    it 'should require origin country' do
      t = nil
      expect {t = TradePreferenceProgram.create(name:'TPP', destination_country_id:create(:country).id)}.to_not change(TradePreferenceProgram, :count)
      expect(t.errors[:origin_country_id].size).to eq(1)
    end
    it 'should require destination country' do
      t = nil
      expect {t = TradePreferenceProgram.create(name:'TPP', origin_country_id:create(:country).id)}.to_not change(TradePreferenceProgram, :count)
      expect(t.errors[:destination_country_id].size).to eq(1)
    end
    it 'should require name' do
      t = nil
      expect {t = TradePreferenceProgram.create(origin_country_id:create(:country).id, destination_country_id:create(:country).id)}.to_not change(TradePreferenceProgram, :count)
      expect(t.errors[:name].size).to eq(1)
    end
  end
  context 'security' do
    let :prep_lane do
      tl = double(:trade_lane)
      allow(tl).to receive(:can_view?).and_return true
      allow(tl).to receive(:can_edit?).and_return true
      tl
    end
    let :prep do
      lane = prep_lane
      tpp = TradePreferenceProgram.new
      allow(tpp).to receive(:trade_lane).and_return lane
      [tpp, lane]
    end
    describe '#can_view?' do
      it 'should allow if can view associated trade lane' do
        tpp = prep.first
        expect(tpp.can_view?(double(:user))).to be_truthy
      end

      it 'should not allow if cannot view associated trade lane' do
        tpp, lane = prep
        allow(lane).to receive(:can_view?).and_return false
        expect(tpp.can_view?(double(:user))).to be_falsey
      end
    end
    describe '#can_edit?' do
      it 'should allow if can edit associated trade lane' do
        tpp = prep.first
        expect(tpp.can_edit?(double(:user))).to be_truthy
      end

      it 'should not allow if cannot edit associated trade lane' do
        tpp, lane = prep
        allow(lane).to receive(:can_edit?).and_return false
        expect(tpp.can_edit?(double(:user))).to be_falsey
      end
    end
  end
  describe '#search_secure' do
    it 'should secure if user cannot view trade lanes' do
      create(:trade_preference_program)
      u = double(:user)
      allow(u).to receive(:view_trade_preference_programs?).and_return false
      expect(described_class.search_secure(u, described_class).to_a).to eq []
    end
    it 'should be open if user can view trade lanes' do
      tpp = create(:trade_preference_program)
      u = double(:user)
      allow(u).to receive(:view_trade_preference_programs?).and_return true
      expect(described_class.search_secure(u, described_class).to_a).to eq [tpp]
    end
  end
  describe '#trade_lane' do
    it 'should return associated trade lane' do
      lane = create(:trade_lane)
      tpp = create(:trade_preference_program, origin_country:lane.origin_country, destination_country:lane.destination_country)

      expect(tpp.trade_lane).to eq lane
    end
  end
  describe '#long_name' do
    it "should return name and countries" do
      ca = create(:country, iso_code:'CA')
      us = create(:country, iso_code:'US')
      tpp = TradePreferenceProgram.new(name:'hello', origin_country:ca, destination_country:us)
      expect(tpp.long_name).to eq 'CA > US: hello'
    end
  end
end
