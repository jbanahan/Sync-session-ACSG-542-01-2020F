describe ProductTradePreferenceProgram do
  context 'security' do
    it "should allow view if user can view both product and trade preference program" do
      u = double(:user)
      ptpp = FactoryBot(:product_trade_preference_program)
      expect(ptpp.product).to receive(:can_view?).with(u).and_return true
      expect(ptpp.trade_preference_program).to receive(:can_view?).with(u).and_return true

      expect(ptpp.can_view?(u)).to be_truthy
    end
    it "should not allow view if user cannot view trade_preference_program" do
      u = double(:user)
      ptpp = FactoryBot(:product_trade_preference_program)
      allow(ptpp.product).to receive(:can_view?).and_return true
      expect(ptpp.trade_preference_program).to receive(:can_view?).with(u).and_return false

      expect(ptpp.can_view?(u)).to be_falsey
    end
    it "should not allow view if user cannot view product" do
      u = double(:user)
      ptpp = FactoryBot(:product_trade_preference_program)
      expect(ptpp.product).to receive(:can_view?).with(u).and_return false
      allow(ptpp.trade_preference_program).to receive(:can_view?).and_return true

      expect(ptpp.can_view?(u)).to be_falsey
    end
  end
end
