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
  describe :all_attachments do
    it "should sort by attachment type then attached file name then id" do
      p = Factory(:product)
      third = p.attachments.create!(:attachment_type=>"B",:attached_file_name=>"A")
      second = p.attachments.create!(:attachment_type=>"A",:attached_file_name=>"R")
      first = p.attachments.create!(:attachment_type=>"A",:attached_file_name=>"Q")
      fourth = p.attachments.create!(:attachment_type=>"B",:attached_file_name=>"A")
      r = p.all_attachments
      r[0].should == first
      r[1].should == second
      r[2].should == third
      r[3].should == fourth
    end
  end
end
