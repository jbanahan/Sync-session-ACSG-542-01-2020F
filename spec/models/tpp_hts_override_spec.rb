require 'spec_helper'

describe TppHtsOverride do
  context 'security' do
    describe '#can_view?' do
      it 'should defer to trade_preference_program' do
        u = double(:user)
        t = TppHtsOverride.new
        tpp = TradePreferenceProgram.new
        t.trade_preference_program = tpp

        expect(tpp).to receive(:can_view?).with(u).and_return('x')

        expect(t.can_view?(u)).to eq 'x'
      end
    end
    describe '#can_edit?' do
      it 'should defer to trade_preference_program' do
        u = double(:user)
        t = TppHtsOverride.new
        tpp = TradePreferenceProgram.new
        t.trade_preference_program = tpp

        expect(tpp).to receive(:can_edit?).with(u).and_return('x')

        expect(t.can_edit?(u)).to eq 'x'
      end
    end

    describe '#search_secure' do
      it 'should delegate to trade preference program' do
        u = double('user')
        expect(TradePreferenceProgram).to receive(:search_where).with(u).and_return('99=99')
        qry = described_class.search_secure(u,described_class).to_sql
        expect(qry).to match(/tpp_hts_overrides\.trade_preference_program_id IN \(SELECT id FROM trade_preference_programs WHERE 99=99\)/)
      end
    end
  end
  describe '#active' do
    before :each do
      # creating one preference program to make the test run faster
      @tpp = Factory(:trade_preference_program)
    end
    it 'should only find active override' do

      # old one, don't find it
      old_one = Factory(:tpp_hts_override, start_date: Date.new(1900,1,1), end_date: Date.new(1900,1,2), trade_preference_program: @tpp)
      expect(old_one).to_not be_active

      # not active yet, don't find it
      new_one = Factory(:tpp_hts_override, start_date: Date.new(2999,1,1), end_date: Date.new(2999,1,2), trade_preference_program: @tpp)
      expect(new_one).to_not be_active

      # active, find it
      find_me = Factory(:tpp_hts_override, start_date: Date.new(1900,1,1), end_date: Date.new(2999,1,1), trade_preference_program: @tpp)
      expect(find_me).to be_active

      expect(TppHtsOverride.active.to_a).to eq [find_me]
    end
    it 'should take effective date parameters' do
      effective_date = Date.new(2199,1,1)
      dont_find = Factory(:tpp_hts_override, start_date: Date.new(1900,1,1), end_date: Date.new(2100,1,1), trade_preference_program: @tpp)
      expect(dont_find).to_not be_active(effective_date)

      find_me = Factory(:tpp_hts_override, start_date: Date.new(1900,1,1), end_date: Date.new(2999, 1, 1), trade_preference_program: @tpp)
      expect(find_me).to be_active(effective_date)

      expect(TppHtsOverride.active(effective_date).to_a).to eq [find_me]
    end
  end
end
