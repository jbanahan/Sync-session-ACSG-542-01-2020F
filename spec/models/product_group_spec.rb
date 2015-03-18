require 'spec_helper'

describe ProductGroup do
  describe :in_use do
    it "should be false if no links" do
      expect(ProductGroup.new).to_not be_in_use
    end
    it "should be true if linked to vendor_product_group_assignments" do |variable|
      c = Factory(:company,vendor:true)
      pg = Factory(:product_group)
      pg.vendors << c
      pg.save!
      expect(pg).to be_in_use
    end
  end

  describe :before_destroy do
    it "should error if product in use" do
      c = Factory(:company,vendor:true)
      pg = Factory(:product_group)
      pg.vendors << c
      pg.save!
      expect{pg.destroy}.to_not change(ProductGroup,:count)
      expect(pg.errors).to_not be_blank
    end
    it "should pass if product not in use" do
      pg = Factory(:product_group)
      expect{pg.destroy}.to change(ProductGroup,:count).from(1).to(0)
      expect(pg.errors).to be_blank
    end
  end
end
