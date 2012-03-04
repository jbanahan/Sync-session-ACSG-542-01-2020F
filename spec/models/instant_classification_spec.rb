require 'spec_helper'

describe InstantClassification do
  describe "find by product" do
    before :each do
      @first_ic = InstantClassification.create!(:name=>'bulk test',:rank=>1)
      @first_ic.search_criterions.create!(:model_field_uid=>'prod_uid',:operator=>'sw',:value=>'bulk')
      @second_ic = InstantClassification.create!(:name=>'bulk test 2',:rank=>2) #should match this one
      @second_ic.search_criterions.create!(:model_field_uid=>'prod_uid',:operator=>'eq',:value=>'findme')
      @third_ic = InstantClassification.create!(:name=>'bulk test 3',:rank=>3) #this one would match, but we shouldn't hit it because second_ic will match first
      @third_ic.search_criterions.create!(:model_field_uid=>'prod_uid',:operator=>'ew',:value=>'me')
    end
    it "should find a match" do
      p = Factory(:product,:unique_identifier=>'findme')
      InstantClassification.find_by_product(p,Factory(:user)).should == @second_ic
    end
    it "should not find a match" do
      p = Factory(:product,:unique_identifier=>'dont')
      InstantClassification.find_by_product(p,Factory(:user)).should be_nil
    end
  end
  describe "test" do
    before :each do
      @ic = InstantClassification.create!(:name=>"ic1")
      @ic.search_criterions.create!(:model_field_uid=>'prod_uid',:operator=>'eq',:value=>'puidict')
    end
    it "should match" do
      @ic.test?(Factory(:product,:unique_identifier=>'puidict'),Factory(:user)).should be_true 
    end
    it "shouldn't match" do
      @ic.test?(Factory(:product,:unique_identifier=>'not puidict'),Factory(:user)).should be_false 
    end
  end
end
