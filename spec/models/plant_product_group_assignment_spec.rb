require 'spec_helper'

describe PlantProductGroupAssignment do
  before :each do
    @plant = Factory(:plant)
    @product_group = Factory(:product_group)
    @ppga = @plant.plant_product_group_assignments.create!(product_group_id:@product_group.id)
    @user = double(:user)
  end
  describe :can_view? do
    it "should view if user can view plant" do
      @plant.stub(:can_view?).and_return true
      expect(@ppga.can_view?(@user)).to be_true
    end
    it "should not edit if user cannot edit plant" do
      @plant.stub(:can_view?).and_return false
      expect(@ppga.can_view?(@user)).to be_false
    end
  end
  describe :can_edit? do
    it "should edit if user can edit plant" do
      @plant.stub(:can_edit?).and_return true
      expect(@ppga.can_edit?(@user)).to be_true
    end
    it "should not edit if user cannot edit plant" do
      @plant.stub(:can_edit?).and_return false
      expect(@ppga.can_edit?(@user)).to be_false
    end
  end
end
