describe TradeLane do
  context 'validations' do
    it "should require destination country" do
      origin = Factory(:country)
      t = nil
      expect {t = TradeLane.create(origin_country_id:origin.id)}.to_not change(TradeLane, :count)
      expect(t.errors[:destination_country_id].size).to eq(1)
    end
    it "should require origin country" do
      destination = Factory(:country)
      t = nil
      expect {t = TradeLane.create(destination_country_id:destination.id)}.to_not change(TradeLane, :count)
      expect(t.errors[:origin_country_id].size).to eq(1)
    end
    it "should require unique origin/destination country pair" do
      good_lane = Factory(:trade_lane)
      t = nil
      expect {t = TradeLane.create(destination_country_id:good_lane.destination_country_id, origin_country_id:good_lane.origin_country_id)}.to_not change(TradeLane, :count)
      expect(t.errors[:destination_country_id].size).to eq(1)
    end
  end
  context 'security' do
    describe '#can_view?' do
      it "should allow user who can view trade_lane" do
        u = User.new
        allow(u).to receive(:view_trade_lanes?).and_return true
        expect(TradeLane.new.can_view?(u)).to be_truthy
      end
      it "should not allow user who cannot view trade lanes" do
        u = User.new
        allow(u).to receive(:view_trade_lanes?).and_return false
        expect(TradeLane.new.can_view?(u)).to be_falsey
      end
    end
    describe '#can_edit?' do
      it "should allow user who can edit trade_lane" do
        u = User.new
        allow(u).to receive(:edit_trade_lanes?).and_return true
        expect(TradeLane.new.can_edit?(u)).to be_truthy
      end
      it "should not allow user who cannot edit trade lanes" do
        u = User.new
        allow(u).to receive(:edit_trade_lanes?).and_return false
        expect(TradeLane.new.can_edit?(u)).to be_falsey
      end
    end
    describe '#search_where' do
      it "should return all for user who can view trade lanes" do
        u = User.new
        allow(u).to receive(:view_trade_lanes?).and_return true
        expect(TradeLane.search_where(u)).to eq '1=1'
      end
      it "should return none for user who cannot view trade lanes" do
        u = User.new
        allow(u).to receive(:view_trade_lanes?).and_return false
        expect(TradeLane.search_where(u)).to eq '1=0'
      end
    end
    describe '#search_secure' do
      it "should find trade lane if user can view" do
        t = Factory(:trade_lane)
        u = User.new
        allow(u).to receive(:view_trade_lanes?).and_return true
        expect(TradeLane.search_secure(u, TradeLane).to_a).to eq [t]
      end
      it "should not find trade lane if user cannot view" do
        Factory(:trade_lane)
        u = User.new
        allow(u).to receive(:view_trade_lanes?).and_return false
        expect(TradeLane.search_secure(u, TradeLane)).to be_empty
      end
    end
  end
  describe '#trade_preference_programs' do
    it 'should return preference programs' do
      tpp1 = Factory(:trade_preference_program)
      tpp2 = Factory(:trade_preference_program, origin_country_id:tpp1.origin_country_id, destination_country_id:tpp1.destination_country_id)
      lane = Factory(:trade_lane, origin_country_id:tpp1.origin_country_id, destination_country_id:tpp1.destination_country_id)

      expect(lane.trade_preference_programs.to_a).to eq [tpp1, tpp2]
    end
  end
end
