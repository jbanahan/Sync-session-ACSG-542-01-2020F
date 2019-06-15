describe TradeLanesController do
  before :each do
    @u = Factory(:user)
    allow_any_instance_of(User).to receive(:view_trade_lanes?).and_return true
    sign_in_as @u
  end
  describe '#index' do
    it 'should show if user can view trade lanes' do
      get :index
      expect(response).to be_success
    end
    it 'should not show if user cannot view trade lanes' do
      allow_any_instance_of(User).to receive(:view_trade_lanes?).and_return false
      get :index
      expect(response).to be_redirect
    end
  end
end
