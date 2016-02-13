require 'spec_helper'

describe ProductVendorAssignment do
  context :security do
    before :each do
      @u = Factory(:user)
      @pva = Factory(:product_vendor_assignment)
    end
    describe 'can_view?' do
      it "should allow if user can view vendor" do
        @pva.vendor.should_receive(:can_view?).with(@u).and_return true
        expect(@pva.can_view?(@u)).to be_true
      end
      it "should not allow if user cannot view vendor" do
        @pva.vendor.should_receive(:can_view?).with(@u).and_return false
        expect(@pva.can_view?(@u)).to be_false
      end
    end
    describe 'can_edit?' do
      it "should allow if user can edit vendor & product" do
        @pva.vendor.stub(:can_edit?).with(@u).and_return true
        @pva.product.stub(:can_edit?).with(@u).and_return true
        expect(@pva.can_edit?(@u)).to be_true
      end
      it "should not allow if user cannot edit vendor" do
        @pva.vendor.stub(:can_edit?).with(@u).and_return false
        @pva.product.stub(:can_edit?).with(@u).and_return true
        expect(@pva.can_edit?(@u)).to be_false
      end
      it "should not allow if user cannot edit product" do
        @pva.vendor.stub(:can_edit?).with(@u).and_return true
        @pva.product.stub(:can_edit?).with(@u).and_return false
        expect(@pva.can_edit?(@u)).to be_false
      end
    end
  end
end
