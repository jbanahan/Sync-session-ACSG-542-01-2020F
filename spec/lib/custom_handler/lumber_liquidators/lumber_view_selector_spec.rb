describe OpenChain::CustomHandler::LumberLiquidators::LumberViewSelector do

  describe '#order_view' do
    it "should return view page" do
      o = double(:order)
      u = double(:user)
      expect(described_class.order_view(o, u)).to eq '/custom_view/ll/order_view.html'
    end
  end

  describe '#shipment_view' do
    it 'should return view page' do
      s = double(:shipment)
      u = double(:user)
      expect(described_class.shipment_view(s, u)).to eq '/custom_view/ll/shipment_view.html'
    end
  end
end
