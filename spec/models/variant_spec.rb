require 'spec_helper'

describe Variant do
  describe '#can_view?' do
    before :each do
      @v = Factory(:variant)
      @u = Factory(:user)
    end
    it 'should be visible if user can view product' do
      @v.product.should_receive(:can_view?).with(@u).and_return true
      expect(@v.can_view?(@u)).to be_true
    end
    it 'should not be visible if user cannot view product' do
      @v.product.should_receive(:can_view?).with(@u).and_return false
      expect(@v.can_view?(@u)).to be_false
    end
  end
end
