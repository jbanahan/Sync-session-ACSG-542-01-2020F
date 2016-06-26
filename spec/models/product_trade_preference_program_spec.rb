require 'spec_helper'

describe ProductTradePreferenceProgram do
  context 'security' do
    it "should allow view if user can view both product and trade preference program" do
      u = double(:user)
      ptpp = Factory(:product_trade_preference_program)
      ptpp.product.should_receive(:can_view?).with(u).and_return true
      ptpp.trade_preference_program.should_receive(:can_view?).with(u).and_return true

      expect(ptpp.can_view?(u)).to be_true
    end
    it "should not allow view if user cannot view trade_preference_program" do
      u = double(:user)
      ptpp = Factory(:product_trade_preference_program)
      ptpp.product.stub(:can_view?).and_return true
      ptpp.trade_preference_program.should_receive(:can_view?).with(u).and_return false

      expect(ptpp.can_view?(u)).to be_false
    end
    it "should not allow view if user cannot view product" do
      u = double(:user)
      ptpp = Factory(:product_trade_preference_program)
      ptpp.product.should_receive(:can_view?).with(u).and_return false
      ptpp.trade_preference_program.stub(:can_view?).and_return true

      expect(ptpp.can_view?(u)).to be_false
    end
  end
end
