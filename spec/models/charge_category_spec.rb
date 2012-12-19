require 'spec_helper'

describe ChargeCategory do
  context "validations" do
    before :each do
      @comp1 = Factory(:company)
      @comp1.charge_categories.create!(:charge_code=>'A',:category=>'X')
    end
    it "should validate unique charge_code per company" do
      c2 = @comp1.charge_categories.new(:charge_code=>'A',:category=>'Y')
      c2.save.should be_false
    end
    it "should allow charge_code repeats across companies" do
      c = Factory(:company).charge_categories.create(:charge_code=>'A',:category=>'Y')
      c.id.should > 0
    end
  end
end
