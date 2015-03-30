require 'spec_helper'

describe Plant do
  describe :can_view? do
    it "should allow if user can view company as vendor" do
      Company.any_instance.stub(:can_view_as_vendor?).and_return true
      Company.any_instance.stub(:can_view?).and_return false #to make sure we're not testing the wrong thing
      u = double(:user)
      expect(Factory(:plant).can_view?(u)).to be_true
    end
    it "should allow if user can view company" do
      Company.any_instance.stub(:can_view?).and_return true
      Company.any_instance.stub(:can_view_as_vendor?).and_return false #to make sure we're not testing the wrong thing
      u = double(:user)
      expect(Factory(:plant).can_view?(u)).to be_true
    end
    it "should not allow if user cannot view company or company as vendor" do
      Company.any_instance.stub(:can_view?).and_return false
      Company.any_instance.stub(:can_view_as_vendor?).and_return false
      u = double(:user)
      expect(Factory(:plant).can_view?(u)).to be_false
    end
  end
  describe :can_attach? do
    it "should allow if user can attach to company" do
      Company.any_instance.stub(:can_attach?).and_return true
      u = double(:user)
      expect(Factory(:plant).can_attach?(u)).to be_true
    end
    it "should not allow if user cannot attach to company" do
      Company.any_instance.stub(:can_attach?).and_return false
      u = double(:user)
      expect(Factory(:plant).can_attach?(u)).to be_false
    end
  end
  describe :can_edit? do
    it "should allow if user can edit company" do
      Company.any_instance.stub(:can_edit?).and_return true
      u = double(:user)
      expect(Factory(:plant).can_edit?(u)).to be_true
    end
    it "should not allow if user cannot edit company" do
      Company.any_instance.stub(:can_edit?).and_return false
      u = double(:user)
      expect(Factory(:plant).can_edit?(u)).to be_false
    end
  end

  describe :in_use? do
    it "should return false" do
      expect(Plant.new.in_use?).to be_false
    end
    it "should not allow delete if in_use?" do
      plant = Factory(:plant)
      plant.stub(:in_use?).and_return(true)
      expect{plant.destroy}.to_not change(Plant,:count)
    end
    it "should allow delete if not in_use?" do
      plant = Factory(:plant)
      plant.stub(:in_use?).and_return(false)
      expect{plant.destroy}.to change(Plant,:count).from(1).to(0)
    end
  end

  describe :unassigned_product_groups do
    it "shoud return unassigned product groups" do
      plant = Factory(:plant)
      pg1 = Factory(:product_group, name: 'PGA')
      pg2 = Factory(:product_group, name: 'PGB')
      plant.product_groups << pg1
      expect(plant.unassigned_product_groups.to_a).to eq [pg2]
    end
  end
end
