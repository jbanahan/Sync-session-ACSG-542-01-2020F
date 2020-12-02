describe Variant do
  describe '#can_view?' do
    before :each do
      @v = create(:variant)
      @u = create(:user)
    end
    it 'should be visible if user can view product' do
      expect(@v.product).to receive(:can_view?).with(@u).and_return true
      expect(@v.can_view?(@u)).to be_truthy
    end
    it 'should not be visible if user cannot view product' do
      expect(@v.product).to receive(:can_view?).with(@u).and_return false
      expect(@v.can_view?(@u)).to be_falsey
    end
  end
end
