require 'spec_helper'

describe ProductGroup do
  describe :in_use do
    it "should be false if no links" do
      expect(ProductGroup.new).to_not be_in_use
    end
  end

  describe :before_destroy do
    it "should error if product in use" do
      pg = Factory(:product_group)
      pg.stub(:in_use?).and_return true
      pg.save!
      expect{pg.destroy}.to_not change(ProductGroup,:count)
      expect(pg.errors).to_not be_blank
    end
    it "should pass if product not in use" do
      pg = Factory(:product_group)
      pg.stub(:in_use?).and_return false
      expect{pg.destroy}.to change(ProductGroup,:count).from(1).to(0)
      expect(pg.errors).to be_blank
    end
  end
end
