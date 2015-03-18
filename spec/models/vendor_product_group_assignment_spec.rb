require 'spec_helper'

describe VendorProductGroupAssignment do
  describe :can_view? do
    it "should allow if user can view vendor" do
      u = double(:user)
      c = Company.new
      c.should_receive(:can_view_as_vendor?).with(u).and_return true
      expect(VendorProductGroupAssignment.new(vendor:c).can_view?(u)).to be_true
    end
    it "should not allow if user cannot view vendor" do
      u = double(:user)
      c = Company.new
      c.should_receive(:can_view_as_vendor?).and_return false
      expect(VendorProductGroupAssignment.new(vendor:c).can_view?(u)).to be_false

    end
    it "should not allow if vendor is nil" do
      u = double(:user)
      expect(VendorProductGroupAssignment.new.can_view?(u)).to be_false
    end
  end
end
