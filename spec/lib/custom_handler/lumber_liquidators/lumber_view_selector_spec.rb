require 'spec_helper'

describe OpenChain::CustomHandler::LumberLiquidators::LumberViewSelector do

  describe '#order_view' do
    it "should return view page" do
      o = Factory(:order)
      u = Factory(:user)
      expect(described_class.order_view(o,u)).to eq '/custom_view/ll/order_view.html'
    end
  end
end