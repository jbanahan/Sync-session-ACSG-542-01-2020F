require 'spec_helper'

describe ProductVendorAssignment do
  context "security" do
    before :each do
      @u = Factory(:user)
      @pva = Factory(:product_vendor_assignment)
    end
    describe '#can_view?' do
      it "should allow if user can view vendor" do
        expect(@pva.vendor).to receive(:can_view?).with(@u).and_return true
        expect(@pva.can_view?(@u)).to be_truthy
      end
      it "should not allow if user cannot view vendor" do
        expect(@pva.vendor).to receive(:can_view?).with(@u).and_return false
        expect(@pva.can_view?(@u)).to be_falsey
      end
    end
    describe '#can_edit?' do
      it "should allow if user can edit vendor & product" do
        allow(@pva.vendor).to receive(:can_edit?).with(@u).and_return true
        allow(@pva.product).to receive(:can_edit?).with(@u).and_return true
        expect(@pva.can_edit?(@u)).to be_truthy
      end
      it "should not allow if user cannot edit vendor" do
        allow(@pva.vendor).to receive(:can_edit?).with(@u).and_return false
        allow(@pva.product).to receive(:can_edit?).with(@u).and_return true
        expect(@pva.can_edit?(@u)).to be_falsey
      end
      it "should not allow if user cannot edit product" do
        allow(@pva.vendor).to receive(:can_edit?).with(@u).and_return true
        allow(@pva.product).to receive(:can_edit?).with(@u).and_return false
        expect(@pva.can_edit?(@u)).to be_falsey
      end
    end
  end
  describe '#search_secure' do
    it "should allow if pva linked to vendor user can view" do
      v = Factory(:vendor)
      u = Factory(:user,company:v)
      pva = Factory(:product_vendor_assignment,vendor:v)
      Factory(:product_vendor_assignment) #don't find this one

      expect(described_class.search_secure(u,described_class).to_a).to eq [pva]
    end
  end
end
