require 'spec_helper'

describe CoreObjectSupport do
  describe :view_url do
    before :each do
      @rh = "x.y.z"
      MasterSetup.get.update_attributes(:request_host=>@rh)
    end
    it "should make url based on request_host" do
      p = Factory(:product)
      p.view_url.should == "http://#{@rh}/products/#{p.id}"
    end
    it "should raise exception if id not set" do
      lambda {Product.new.view_url}.should raise_error
    end
    it "should raise exception if request host not set" do
      MasterSetup.get.update_attributes(:request_host=>nil)
      lambda {Factory(:product).view_url}.should raise_error
    end
  end
end
